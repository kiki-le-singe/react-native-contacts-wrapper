//
//  RCTContactsWrapper.m
//  RCTContactsWrapper
//
//  Created by Oliver Jacobs on 15/06/2016.
//  Copyright © 2016 Facebook. All rights reserved.
//

@import Foundation;
#import "RCTContactsWrapper.h"
@interface RCTContactsWrapper()

@property(nonatomic, retain) RCTPromiseResolveBlock _resolve;
@property(nonatomic, retain) RCTPromiseRejectBlock _reject;

@end


@implementation RCTContactsWrapper

int _requestCode;
const int REQUEST_CONTACT = 1;
const int REQUEST_EMAIL = 2;


RCT_EXPORT_MODULE(ContactsWrapper);

/* Get basic contact data as JS object */
RCT_EXPORT_METHOD(getContact:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
  {
    self._resolve = resolve;
    self._reject = reject;
    _requestCode = REQUEST_CONTACT;
    
    [self launchContacts];
    
    
  }

/* Get ontact email as string */
RCT_EXPORT_METHOD(getEmail:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  self._resolve = resolve;
  self._reject = reject;
  _requestCode = REQUEST_EMAIL;
  
  [self launchContacts];
  
  
}


/**
 Launch the contacts UI
 */
-(void) launchContacts {
  
  UIViewController *picker;
  if([CNContactPickerViewController class]) {
    //if(NSClassFromString(@"CNContactPickerViewController")){
    //iOS 9+
    picker = [[CNContactPickerViewController alloc] init];
    ((CNContactPickerViewController *)picker).delegate = self;
  } else {
    //iOS 8 and below
    picker = [[ABPeoplePickerNavigationController alloc] init];
    [((ABPeoplePickerNavigationController *)picker) setPeoplePickerDelegate:self];
  }
  //Launch Contact Picker or Address Book View Controller
  UIViewController *root = [[[UIApplication sharedApplication] delegate] window].rootViewController;
  [root presentViewController:picker animated:YES completion:nil];
  
  
}


#pragma mark - RN Promise Events

- (void)pickerCancelled {
  self._reject(@"E_CONTACT_CANCELLED", @"Cancelled", nil);
}


- (void)pickerError {
  self._reject(@"E_CONTACT_EXCEPTION", @"Unknown Error", nil);
}

- (void)pickerNoEmail {
  self._reject(@"E_CONTACT_NO_EMAIL", @"No email found for contact", nil);
}

-(void)emailPicked:(NSString *)email {
  self._resolve(email);
}


-(void)contactPicked:(NSDictionary *)contactData {
  self._resolve(contactData);
}


#pragma mark - Shared functions


- (NSMutableDictionary *) emptyContactDict {
  return [
    [NSMutableDictionary alloc]
      initWithObjects:@[@"", @"", @"", @"", @"", @""]
      forKeys:@[@"givenName", @"middleName", @"familyName", @"fullName", @"phoneNumbers", @"email"]
  ];
}

/**
 Return full name as single string from first last and middle name strings, which may be empty
 */
-(NSString *) getFullNameForFirst:(NSString *)fName middle:(NSString *)mName last:(NSString *)lName {
  //Check whether to include middle name or not
  NSArray *names = (mName.length > 0) 
    ? [NSArray arrayWithObjects:fName, mName, lName, nil]
    : [NSArray arrayWithObjects:fName, lName, nil];
  return [names componentsJoinedByString:@" "];
}



#pragma mark - Event handlers - iOS 9+

- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact {
  switch(_requestCode){
    case REQUEST_CONTACT:
    {
      /* Return NSDictionary ans JS Object to RN, containing basic contact data
       This is a starting point, in future more fields should be added, as required.
       */
      NSMutableDictionary *contactData = [self emptyContactDict];
      
      NSString *fullName = [self getFullNameForFirst:contact.givenName middle:contact.middleName last:contact.familyName ];

      //Return full name
      [contactData setValue:fullName forKey:@"fullName"];
      [contactData setValue:contact.givenName forKey:@"givenName"];
      [contactData setValue:contact.middleName forKey:@"middleName"];
      [contactData setValue:contact.familyName forKey:@"familyName"];
      
      NSMutableArray *phoneNumbers = [[NSMutableArray alloc] init];
      for(CFIndex i=0;i<[contact.phoneNumbers count];i++) {
        NSMutableDictionary* phone = [NSMutableDictionary dictionary];
        CNLabeledValue *lv = ((CNLabeledValue *)contact.phoneNumbers[i]);
        [phone setValue: ((CNPhoneNumber *)lv.value).stringValue forKey:@"number"];
        [phone setValue: [CNLabeledValue localizedStringForLabel:lv.label] forKey:@"label"];
        [phoneNumbers addObject:phone];
      }
      [contactData setObject:phoneNumbers forKey:@"phoneNumbers"];


      NSMutableArray *emailAddresses = [[NSMutableArray alloc] init];
      for(CFIndex i=0;i<[contact.emailAddresses count];i++) {
        NSMutableDictionary* email = [NSMutableDictionary dictionary];
        CNLabeledValue *lv = ((CNLabeledValue *)contact.emailAddresses[i]);
        [email setValue: lv.value forKey:@"email"];
        [email setValue: [CNLabeledValue localizedStringForLabel:lv.label] forKey:@"label"];
        [emailAddresses addObject:email];
      }
      [contactData setObject:emailAddresses forKey:@"emailAddresses"];

      [self contactPicked:contactData];
    }
      break;
    case REQUEST_EMAIL :
    {
      // Return Only email address as string 
      if([contact.emailAddresses count] < 1) {
        [self pickerNoEmail];
        return;
      }
      
      CNLabeledValue *email = contact.emailAddresses[0].value;
      [self emailPicked:email];
    }
      break;
    default:
      //Should never happen, but just in case, reject promise
      [self pickerError];
    break;
  }
  
  
}


- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker {
  [self pickerCancelled];
}



#pragma mark - Event handlers - iOS 8

/* Same functionality as above, implemented using iOS8 AddressBook library */
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker didSelectPerson:(ABRecordRef)person {
  switch(_requestCode) {
    case(REQUEST_CONTACT):
    {
      
      /* Return NSDictionary ans JS Object to RN, containing basic contact data
       This is a starting point, in future more fields should be added, as required.
       This could also be extended to return arrays of phone numbers, email addresses etc. instead of jsut first found
       */
      NSMutableDictionary *contactData = [self emptyContactDict];
            NSString *fNameObject, *mNameObject, *lNameObject;
      fNameObject = (__bridge NSString *) ABRecordCopyValue(person, kABPersonFirstNameProperty);
      mNameObject = (__bridge NSString *) ABRecordCopyValue(person, kABPersonMiddleNameProperty);
      lNameObject = (__bridge NSString *) ABRecordCopyValue(person, kABPersonLastNameProperty);
      
      NSString *fullName = [self getFullNameForFirst:fNameObject middle:mNameObject last:lNameObject];
      
      //Return full name
      [contactData setValue:fullName forKey:@"fullName"];
      [contactData setValue:fNameObject forKey:@"givenName"];
      [contactData setValue:mNameObject forKey:@"middleName"];
      [contactData setValue:lNameObject forKey:@"familyName"];
      
      //Return first phone numbers
      NSMutableArray *phoneNumberList = [[NSMutableArray alloc] init];

      ABMultiValueRef phoneNumbers = ABRecordCopyValue(person, kABPersonPhoneProperty);
      if (phoneNumbers) {
        CFIndex numberOfPhoneNumbers = ABMultiValueGetCount(phoneNumbers);
        for (CFIndex i = 0; i < numberOfPhoneNumbers; i++) {
          NSMutableDictionary* phone = [NSMutableDictionary dictionary];
          CFStringRef label = ABMultiValueCopyLabelAtIndex(phoneNumbers, i);
          CFStringRef number = ABMultiValueCopyValueAtIndex(phoneNumbers, i);
          if (number) {
            if (label){
              NSString *l=(__bridge NSString *)ABAddressBookCopyLocalizedLabel(label);
              [phone setValue: l forKey:@"label"];
            }
            else [phone setValue: @"Other" forKey:@"label"];
            [phone setValue: (__bridge NSString *)number forKey:@"number"];
            [phoneNumberList addObject:phone];
          }
        }
        CFRelease(phoneNumbers);
      }
      
      [contactData setObject:phoneNumberList forKey:@"phoneNumbers"];

      //Return email list
      NSMutableArray *emailList = [[NSMutableArray alloc] init];
      
      ABMultiValueRef emails = ABRecordCopyValue(person, kABPersonEmailProperty);
      if (emails) {
        CFIndex numberOfEmails = ABMultiValueGetCount(emails);
        for (CFIndex i = 0; i < numberOfEmails; i++) {
          NSMutableDictionary* email = [NSMutableDictionary dictionary];
          CFStringRef label = ABMultiValueCopyLabelAtIndex(emails, i);
          CFStringRef value = ABMultiValueCopyValueAtIndex(emails, i);
          if (value) {
            if (label){
              NSString *l=(__bridge NSString *)ABAddressBookCopyLocalizedLabel(label);
              [email setValue: l forKey:@"label"];
            }
            else [email setValue: @"Other" forKey:@"label"];
            [email setValue: (__bridge NSString *) value forKey:@"email"];
            [emailList addObject:email];
          }
        }
        CFRelease(emails);
      }
      [contactData setObject:emailList forKey:@"emailAddresses"];
      
      [self contactPicked:contactData];
    }
      break;
    case(REQUEST_EMAIL):
    {
      /* Return Only email address as string */
      ABMultiValueRef emailMultiValue = ABRecordCopyValue(person, kABPersonEmailProperty);
      NSArray *emailAddresses = (__bridge NSArray *)ABMultiValueCopyArrayOfAllValues(emailMultiValue);
      if([emailAddresses count] < 1) {
        [self pickerNoEmail];
        return;
      }
      
      [self emailPicked:emailAddresses[0]];
    }
      break;

    default:
      //Should never happen, but just in case, reject promise
      [self pickerError];
      return;
  }
  
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
  [self pickerCancelled];
}






@end

