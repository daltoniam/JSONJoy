JSONJoy
=======

JSONJoy is a joyful little library for iOS and Mac OSX that makes converting and mapping JSON to your objects simple. 

# Example #
So here is an JSON blob we want to parse:
```javascript
{
	"id" : 1
	"first_name": "John",
	"last_name": "Smith",
	"age": 25,
	"address": {
		"id": 1
		"street_address": "21 2nd Street",
	    "city": "New York",
	    "state": "NY",
	    "postal_code": 10021
	 }
	
}
```
And Here is our NSObjects we want to convert it to:

```objective-c

#import "Address.h"

@interface User : NSObject

@property(nonatomic,strong)NSNumber *objectID;
@property(nonatomic,copy)NSString *firstName;
@property(nonatomic,copy)NSString *lastName;
@property(nonatomic,strong)NSNumber *age;
@property(nonatomic,strong)Address *address;

@end

@interface Address : NSObject

@property(nonatomic,strong)NSNumber *objectID;
@property(nonatomic,copy)NSString *streetAddress;
@property(nonatomic,copy)NSString *city;
@property(nonatomic,copy)NSString *state;
@property(nonatomic,strong)NSNumber *postalCode;

@end
```
Take a bunch of error prone boilerplate code like this:
```objective-c
	AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
	[manager GET:@"http://example.com/resources.json" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) 
	{
		NSDictionary* response = responseObject;
        User *john = [[User alloc] init];
        john.objectID = response[@"id"];
        john.firstName = response[@"first_name"];
        john.lastName = response[@"last_name"];
        john.age = response[@"age"];
        NSDictionary* address = response[@"address"];
        john.address.objectID = address[@"id"];
        john.address.streetAddress = address[@"street_address"];
        john.address.city = address[@"city"];
        john.address.state = address[@"state"];
        john.address.postalCode = address[@"postal_code"];	
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
	    NSLog(@"Error: %@", error);
	}];
```
and Joyify it into this:
```objective-c
AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
[manager GET:@"http://example.com/resources.json" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) 
{
	JSONJoy *joy = [JSONJoy JSONJoyWithClass:[User class]];
    User *john = [joy process:responseObject];
} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: %@", error);
}];
```

There is even a category on NSObject to make you be able to do a one liner like this:

```objective-c
AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
[manager GET:@"http://example.com/resources.json" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) 
{
	User *john = [User objectWithJoy:responseObject];
} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
    NSLog(@"Error: %@", error);
}];
```

# Install #

The recommended approach for installing JSONJoy is via the CocoaPods package manager, as it provides flexible dependency management and dead simple installation.

via CocoaPods

Install CocoaPods if not already available:

	$ [sudo] gem install cocoapods
	$ pod setup
Change to the directory of your Xcode project, and Create and Edit your Podfile and add JSONJoy:

	$ cd /path/to/MyProject
	$ touch Podfile
	$ edit Podfile
	platform :ios, '5.0' 
	# Or platform :osx, '10.7'
	pod 'JSONJoy'

Install into your project:

	$ pod install
	
Open your project in Xcode from the .xcworkspace file (not the usual project file)

Via git
just add JSONJoy as a git submodule

# Requirements #

JSONJoy requires at least iOS 5/Mac OSX 10.7 or above.

# License #

JSONJoy is license under the Apache License.

# Contact #

### Dalton Cherry ###
* https://github.com/daltoniam
* http://twitter.com/daltoniam

