/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "CDVContacts.h"
#import <UIKit/UIKit.h>

@implementation CDVContactsPicker
@end

@implementation CDVContactController
@end

@interface CDVContacts()
@property (nonatomic, strong) CNContactStore* contactStore;
@end

@implementation CDVContacts

- (void) pluginInitialize {
	self.contactStore = [[CNContactStore alloc] init];
}

- (bool)existsValue:(NSDictionary*)dict val:(NSString*)expectedValue forKey:(NSString*)key
{
	id val = [dict valueForKey:key];
	bool exists = false;
	
	if (val != nil) {
		exists = [(NSString*)val compare : expectedValue options : NSCaseInsensitiveSearch] == 0;
	}
	
	return exists;
}


- (void)newContact:(CDVInvokedUrlCommand*)command
{
	NSString* callbackId = command.callbackId;
	CNContact* contact = [[CNContact alloc] init];
	CDVContactController* contactController = [CDVContactController viewControllerForNewContact:contact];
	contactController.callbackId = callbackId;
	contactController.delegate = self;
	contactController.allowsEditing = YES;
	
	UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:contactController];
	navController.modalPresentationStyle = UIModalPresentationFormSheet;
	[self.viewController presentViewController:navController animated:YES completion:nil];
}

- (void)displayContact:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
	NSString* contactID = [command argumentAtIndex:0];
    NSDictionary* options = [command argumentAtIndex:1 withDefault:[NSNull null]];
	bool bEdit = [options isKindOfClass:[NSNull class]] ? false : [options[@"allowsEditing"] boolValue];
	
	CNContact* contact = [self.contactStore unifiedContactWithIdentifier:contactID keysToFetch:@[ CNContactNamePrefixKey,
																								 CNContactGivenNameKey,
																								 CNContactMiddleNameKey,
																								 CNContactFamilyNameKey,
																								 CNContactPreviousFamilyNameKey,
																								 CNContactNameSuffixKey,
																								 CNContactNicknameKey,
																								 CNContactOrganizationNameKey,
																								 CNContactDepartmentNameKey,
																								 CNContactJobTitleKey,
																								 CNContactPhoneticGivenNameKey,
																								 CNContactPhoneticMiddleNameKey,
																								 CNContactPhoneticFamilyNameKey,
																								 CNContactPhoneticOrganizationNameKey,
																								 CNContactBirthdayKey,
																								 CNContactNonGregorianBirthdayKey,
																								 CNContactNoteKey,
																								 CNContactImageDataKey,
																								 CNContactThumbnailImageDataKey,
																								 CNContactImageDataAvailableKey,
																								 CNContactTypeKey,
																								 CNContactPhoneNumbersKey,
																								 CNContactEmailAddressesKey,
																								 CNContactPostalAddressesKey,
																								 CNContactDatesKey,
																								 CNContactUrlAddressesKey,
																								 CNContactRelationsKey,
																								 CNContactSocialProfilesKey,
																								 CNContactInstantMessageAddressesKey, CNContactViewController.descriptorForRequiredKeys] error:nil];
	
	if (contact) {
		CDVContactController* contactController = [CDVContactController viewControllerForContact:contact];
		contactController.callbackId = callbackId;
		contactController.delegate = self;
		contactController.allowsEditing = bEdit;

		UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:contactController];
		
		contactController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissContactController)];
		navController.modalPresentationStyle = UIModalPresentationFormSheet;
		[self.viewController presentViewController:navController animated:YES completion:nil];
	}
}

- (void)chooseContact:(CDVInvokedUrlCommand*)command
{
    NSString* callbackId = command.callbackId;
    NSDictionary* options = [command argumentAtIndex:0 withDefault:[NSNull null]];
	
    CDVContactsPicker* pickerController = [[CDVContactsPicker alloc] init];

	pickerController.delegate = self;
    pickerController.callbackId = callbackId;
    pickerController.options = options;
	pickerController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.viewController presentViewController:pickerController animated:YES completion:nil];
}

- (void)pickContact:(CDVInvokedUrlCommand *)command
{
    // mimic chooseContact method call with required for us parameters
    NSArray* desiredFields = [command argumentAtIndex:0 withDefault:[NSArray array]];
    if (desiredFields == nil || desiredFields.count == 0) {
        desiredFields = [NSArray arrayWithObjects:@"*", nil];
    }
    NSMutableDictionary* options = [NSMutableDictionary dictionaryWithCapacity:2];
    
    [options setObject: desiredFields forKey:@"fields"];
    
    NSArray* args = [NSArray arrayWithObjects:options, nil];
    
    CDVInvokedUrlCommand* newCommand = [[CDVInvokedUrlCommand alloc] initWithArguments:args
                 callbackId:command.callbackId
                  className:command.className
                 methodName:command.methodName];

    // First check for Address book permissions
	CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    if (status == CNAuthorizationStatusAuthorized) {
        [self chooseContact:newCommand];
        return;
    }

    CDVPluginResult *errorResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR messageAsInt:PERMISSION_DENIED_ERROR];

    // if the access is already restricted/denied the only way is to fail
    if (status == CNAuthorizationStatusRestricted || status == CNAuthorizationStatusDenied) {
        [self.commandDelegate sendPluginResult: errorResult callbackId:command.callbackId];
        return;
    }

    // if no permissions granted try to request them first
    if (status == CNAuthorizationStatusNotDetermined) {
		[self.contactStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
			if (granted) {
				[self chooseContact:newCommand];
				return;
			}
			
			[self.commandDelegate sendPluginResult: errorResult callbackId:command.callbackId];
		}];
    }
}

- (void)search:(CDVInvokedUrlCommand*)command
{
	//    NSString* callbackId = command.callbackId;
	//    NSArray* fields = [command argumentAtIndex:0];
	//    NSDictionary* findOptions = [command argumentAtIndex:1 withDefault:[NSNull null]];
	//
	//    [self.commandDelegate runInBackground:^{
	//        // from Apple:  Important You must ensure that an instance of ABAddressBookRef is used by only one thread.
	//        // which is why address book is created within the dispatch queue.
	//        // more details here: http: //blog.byadrian.net/2012/05/05/ios-addressbook-framework-and-gcd/
	//        CDVAddressBookHelper* abHelper = [[CDVAddressBookHelper alloc] init];
	//        CDVContacts* __weak weakSelf = self;     // play it safe to avoid retain cycles
	//        // it gets uglier, block within block.....
	//        [abHelper createAddressBook: ^(ABAddressBookRef addrBook, CDVAddressBookAccessError* errCode) {
	//            if (addrBook == NULL) {
	//                // permission was denied or other error - return error
	//                CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageToErrorObject:errCode ? (int)errCode.errorCode:UNKNOWN_ERROR];
	//                [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
	//                return;
	//            }
	//
	//            NSArray* foundRecords = nil;
	//            // get the findOptions values
	//            BOOL multiple = NO;         // default is false
	//            NSString* filter = nil;
	//            NSArray* desiredFields = nil;
	//            if (![findOptions isKindOfClass:[NSNull class]]) {
	//                id value = nil;
	//                id filterValue = [findOptions objectForKey:@"filter"];
	//                BOOL filterValueIsNumber = [filterValue isKindOfClass:[NSNumber class]];
	//                filter = filterValueIsNumber ? [filterValue stringValue] : (NSString *) filterValue;
	//                value = [findOptions objectForKey:@"multiple"];
	//                if ([value isKindOfClass:[NSNumber class]]) {
	//                    // multiple is a boolean that will come through as an NSNumber
	//                    multiple = [(NSNumber*)value boolValue];
	//                    // NSLog(@"multiple is: %d", multiple);
	//                }
	//                desiredFields = [findOptions objectForKey:@"desiredFields"];
	//                // return all fields if desired fields are not explicitly defined
	//                if (desiredFields == nil || desiredFields.count == 0) {
	//                    desiredFields = [NSArray arrayWithObjects:@"*", nil];
	//                }
	//            }
	//
	//            NSDictionary* searchFields = [[CDVContact class] calcReturnFields:fields];
	//            NSDictionary* returnFields = [[CDVContact class] calcReturnFields:desiredFields];
	//
	//            NSMutableArray* matches = nil;
	//            if (!filter || [filter isEqualToString:@""]) {
	//                // get all records
	//                foundRecords = (__bridge_transfer NSArray*)ABAddressBookCopyArrayOfAllPeople(addrBook);
	//                if (foundRecords && ([foundRecords count] > 0)) {
	//                    // create Contacts and put into matches array
	//                    // doesn't make sense to ask for all records when multiple == NO but better check
	//                    int xferCount = multiple == YES ? (int)[foundRecords count] : 1;
	//                    matches = [NSMutableArray arrayWithCapacity:xferCount];
	//
	//                    for (int k = 0; k < xferCount; k++) {
	//                        CDVContact* xferContact = [[CDVContact alloc] initFromABRecord:(__bridge ABRecordRef)[foundRecords objectAtIndex:k]];
	//                        [matches addObject:xferContact];
	//                        xferContact = nil;
	//                    }
	//                }
	//            } else {
	//                foundRecords = (__bridge_transfer NSArray*)ABAddressBookCopyArrayOfAllPeople(addrBook);
	//                matches = [NSMutableArray arrayWithCapacity:1];
	//                BOOL bFound = NO;
	//                int testCount = (int)[foundRecords count];
	//
	//                for (int j = 0; j < testCount; j++) {
	//                    CDVContact* testContact = [[CDVContact alloc] initFromABRecord:(__bridge ABRecordRef)[foundRecords objectAtIndex:j]];
	//                    if (testContact) {
	//                        bFound = [testContact foundValue:filter inFields:searchFields];
	//                        if (bFound) {
	//                            [matches addObject:testContact];
	//                        }
	//                        testContact = nil;
	//                    }
	//                }
	//            }
	//            NSMutableArray* returnContacts = [NSMutableArray arrayWithCapacity:1];
	//
	//            if ((matches != nil) && ([matches count] > 0)) {
	//                // convert to JS Contacts format and return in callback
	//                // - returnFields  determines what properties to return
	//                @autoreleasepool {
	//                    int count = multiple == YES ? (int)[matches count] : 1;
	//
	//                    for (int i = 0; i < count; i++) {
	//                        CDVContact* newContact = [matches objectAtIndex:i];
	//                        NSDictionary* aContact = [newContact toDictionary:returnFields];
	//                        [returnContacts addObject:aContact];
	//                    }
	//                }
	//            }
	//            // return found contacts (array is empty if no contacts found)
	//            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:returnContacts];
	//            [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
	//            // NSLog(@"findCallback string: %@", jsString);
	//
	//            if (addrBook) {
	//                CFRelease(addrBook);
	//            }
	//        }];
	//    }];     // end of workQueue block
	
	return;
}

- (void)save:(CDVInvokedUrlCommand*)command
{
	//    NSString* callbackId = command.callbackId;
	//    NSDictionary* contactDict = [command argumentAtIndex:0];
	//
	//    [self.commandDelegate runInBackground:^{
	//        CDVAddressBookHelper* abHelper = [[CDVAddressBookHelper alloc] init];
	//        CDVContacts* __weak weakSelf = self;     // play it safe to avoid retain cycles
	//
	//        [abHelper createAddressBook: ^(ABAddressBookRef addrBook, CDVAddressBookAccessError* errorCode) {
	//            CDVPluginResult* result = nil;
	//            if (addrBook == NULL) {
	//                // permission was denied or other error - return error
	//                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:errorCode ? (int)errorCode.errorCode:UNKNOWN_ERROR];
	//                [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
	//                return;
	//            }
	//
	//            bool bIsError = FALSE, bSuccess = FALSE;
	//            BOOL bUpdate = NO;
	//            CDVContactError errCode = UNKNOWN_ERROR;
	//            CFErrorRef error;
	//            NSNumber* cId = [contactDict valueForKey:kW3ContactId];
	//            CDVContact* aContact = nil;
	//            ABRecordRef rec = nil;
	//            if (cId && ![cId isKindOfClass:[NSNull class]]) {
	//                rec = ABAddressBookGetPersonWithRecordID(addrBook, [cId intValue]);
	//                if (rec) {
	//                    aContact = [[CDVContact alloc] initFromABRecord:rec];
	//                    bUpdate = YES;
	//                }
	//            }
	//            if (!aContact) {
	//                aContact = [[CDVContact alloc] init];
	//            }
	//
	//            bSuccess = [aContact setFromContactDict:contactDict asUpdate:bUpdate];
	//            if (bSuccess) {
	//                if (!bUpdate) {
	//                    bSuccess = ABAddressBookAddRecord(addrBook, [aContact record], &error);
	//                }
	//                if (bSuccess) {
	//                    bSuccess = ABAddressBookSave(addrBook, &error);
	//                }
	//                if (!bSuccess) {         // need to provide error codes
	//                    bIsError = TRUE;
	//                    errCode = IO_ERROR;
	//                } else {
	//                    // give original dictionary back?  If generate dictionary from saved contact, have no returnFields specified
	//                    // so would give back all fields (which W3C spec. indicates is not desired)
	//                    // for now (while testing) give back saved, full contact
	//                    NSDictionary* newContact = [aContact toDictionary:[CDVContact defaultFields]];
	//                    // NSString* contactStr = [newContact JSONRepresentation];
	//                    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:newContact];
	//                }
	//            } else {
	//                bIsError = TRUE;
	//                errCode = IO_ERROR;
	//            }
	//            CFRelease(addrBook);
	//
	//            if (bIsError) {
	//                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:(int)errCode];
	//            }
	//
	//            if (result) {
	//                [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
	//            }
	//        }];
	//    }];     // end of  queue
}

- (void)remove:(CDVInvokedUrlCommand*)command
{
	//    NSString* callbackId = command.callbackId;
	//    NSNumber* cId = [command argumentAtIndex:0];
	//
	//    CDVAddressBookHelper* abHelper = [[CDVAddressBookHelper alloc] init];
	//    CDVContacts* __weak weakSelf = self;  // play it safe to avoid retain cycles
	//
	//    [abHelper createAddressBook: ^(ABAddressBookRef addrBook, CDVAddressBookAccessError* errorCode) {
	//        CDVPluginResult* result = nil;
	//        if (addrBook == NULL) {
	//            // permission was denied or other error - return error
	//            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:errorCode ? (int)errorCode.errorCode:UNKNOWN_ERROR];
	//            [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
	//            return;
	//        }
	//
	//        bool bIsError = FALSE, bSuccess = FALSE;
	//        CDVContactError errCode = UNKNOWN_ERROR;
	//        CFErrorRef error;
	//        ABRecordRef rec = nil;
	//        if (cId && ![cId isKindOfClass:[NSNull class]] && ([cId intValue] != kABRecordInvalidID)) {
	//            rec = ABAddressBookGetPersonWithRecordID(addrBook, [cId intValue]);
	//            if (rec) {
	//                bSuccess = ABAddressBookRemoveRecord(addrBook, rec, &error);
	//                if (!bSuccess) {
	//                    bIsError = TRUE;
	//                    errCode = IO_ERROR;
	//                } else {
	//                    bSuccess = ABAddressBookSave(addrBook, &error);
	//                    if (!bSuccess) {
	//                        bIsError = TRUE;
	//                        errCode = IO_ERROR;
	//                    } else {
	//                        // set id to null
	//                        // [contactDict setObject:[NSNull null] forKey:kW3ContactId];
	//                        // result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: contactDict];
	//                        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
	//                        // NSString* contactStr = [contactDict JSONRepresentation];
	//                    }
	//                }
	//            } else {
	//                // no record found return error
	//                bIsError = TRUE;
	//                errCode = UNKNOWN_ERROR;
	//            }
	//        } else {
	//            // invalid contact id provided
	//            bIsError = TRUE;
	//            errCode = INVALID_ARGUMENT_ERROR;
	//        }
	//
	//        if (addrBook) {
	//            CFRelease(addrBook);
	//        }
	//        if (bIsError) {
	//            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:(int)errCode];
	//        }
	//        if (result) {
	//            [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
	//        }
	//    }];
	return;
}

#pragma mark -- CNContactViewControllerDelegate
- (void) dismissContactController {
	[self.viewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactViewController:(CDVContactController *)viewController didCompleteWithContact:(nullable CNContact *)contact {
	[viewController dismissViewControllerAnimated:YES completion:nil];
	
	if (!contact) {
		CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:OPERATION_CANCELLED_ERROR] ;
		[self.commandDelegate sendPluginResult:result callbackId:viewController.callbackId];
	}
	else {
		CDVContact* pickedContact = [[CDVContact alloc] initFromCNContact:contact];
		
		CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[pickedContact toDictionary:[CDVContact defaultFields]]];
		[self.commandDelegate sendPluginResult:result callbackId:viewController.callbackId];
	}
}

- (BOOL)contactViewController:(CNContactViewController *)viewController shouldPerformDefaultActionForContactProperty:(CNContactProperty *)property {
	return true;
}


#pragma mark -- CNContactPickerViewControllerDelegate
- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker {
	// return contactId or invalid if none picked
	CDVContactsPicker* cdvPicker = (CDVContactsPicker*)picker;
	
	[[cdvPicker presentingViewController] dismissViewControllerAnimated:YES completion:^{
		CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:OPERATION_CANCELLED_ERROR] ;
		[self.commandDelegate sendPluginResult:result callbackId:cdvPicker.callbackId];
	}];
}

// Called after a contact has been selected by the user.
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact {
    CDVContactsPicker* cdvPicker = (CDVContactsPicker*)picker;
	CDVContact* pickedContact = [[CDVContact alloc] initFromCNContact:contact];
	NSArray* fields = [cdvPicker.options objectForKey:@"fields"];
	NSDictionary* returnFields = [[CDVContact class] calcReturnFields:fields];
	cdvPicker.pickedContactDictionary = [pickedContact toDictionary:returnFields];
	
	[[picker presentingViewController] dismissViewControllerAnimated:YES completion:^{
		CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:cdvPicker.pickedContactDictionary];
		[self.commandDelegate sendPluginResult:result callbackId:cdvPicker.callbackId];
	}];
}

@end

