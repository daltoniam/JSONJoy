////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  JSONJoy.h
//
//  Created by Dalton Cherry on 10/23/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>

@interface JSONJoy : NSObject

///-------------------------------
/// @name Error codes For JSONJoy
///-------------------------------
typedef enum {
    JSONJoyErrorCodeIncorrectType = 1 //this is returned when the expected type does not match in the JSON Object
} JSONJoyErrorCode;

///-------------------------------
/// @name Initalizing a JSONJoy Object
///-------------------------------
/**
 Initializes and returns a JSONJoy object with the class that the json will be converted to.
 @param classObj is the class to map the JSON Object to.
 @return a new JSONJoy object.
*/
-(instancetype)initWithClass:(Class)classObj;


///-------------------------------
/// @name Mapping/Parsing JSON
///-------------------------------
/**
 Adds an array mapping to JSON objects with an a JSON array.
 */
-(void)addArrayClassMap:(NSString*)propertyName class:(Class)classID;

/**
 Runs the conversion process and returns a new object of the class provided.
 @param jsonObj is a json Object or json String to parse.
 @param error returns a valid object if an error occures.
 @return a new parse object of the the class provided.
 */
-(id)process:(id)JSONObject error:(NSError**)error;

/**
 retrieves all the property key names.
 @return an array of all the property keys on the object.
 */
-(NSArray*)propertyKeys;

///-------------------------------
/// @name Factory Methods
///-------------------------------
/**
 Factory method to create a JSONJoy object with a class.
 */
+(instancetype)JSONJoyWithClass:(Class)classType;

///-------------------------------
/// @name Class Methods
///-------------------------------
/**
 @return returns a string formatted to snake case/JSON name.
 @param propName is the property name you want converted. (e.g. avatarThumbUrl to avatar_thumb_url).
 */

+(NSString*)convertToJsonName:(NSString*)propName;

@end

///-------------------------------
/// @name Category Methods
///-------------------------------
@interface NSObject (JSONJoy)

/**
 Category on NSObject that creates a JSONJoy object. The other category methods call this one as well, so you can provide customizations as needed.
 @return a new JSONJoy object.
 */
+(JSONJoy*)jsonMapper;

/**
 Category on NSObject that creates a JSONJoy object and runs the process method to create a new object from the JSONObject provided.
 @param jsonObj is a json Object or json String to parse.
 @return a new parse object of the class running the parsing.
 */
+(id)objectWithJoy:(id)jsonObj;

/**
 Category on NSObject that creates a JSONJoy object and runs the process method to create a new object from the JSONObject provided.
 @param jsonObj is a json Object or json String to parse.
 @param error returns a valid object if an error occures.
 @return a new parse object of the class running the parsing.
 */
+(id)objectWithJoy:(id)jsonObj error:(NSError**)error;

@end
