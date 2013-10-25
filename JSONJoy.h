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
/// @name Initalizing a JSONJoy Object
///-------------------------------
/**
 Initializes and returns a JSONJoy object with the class that the json will be converted to.
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
 */
-(id)process:(id)JSONObject;

///-------------------------------
/// @name Factory Method
///-------------------------------
/**
 Factory method to create a JSONJoy object with a class.
 */
+(instancetype)JSONJoyWithClass:(Class)classType;

@end

///-------------------------------
/// @name Category Methods
///-------------------------------
@interface NSObject (JSONJoy)

/** 
Category on NSObject that creates a JSONJoy object and runs the process method to create a new object from the JSONObject provided.
 */
+(id)objectWithJoy:(id)jsonObj;

@end
