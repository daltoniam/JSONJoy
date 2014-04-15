////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  JSONJoy.m
//
//  Created by Dalton Cherry on 10/23/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import "JSONJoy.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface JSONJoy ()

@property(nonatomic,assign)Class objClass;
@property(nonatomic,strong)NSMutableDictionary* arrayMap;
@property(nonatomic,strong)NSMutableDictionary* propertyClasses;

@end

@implementation JSONJoy

static BOOL isLoose;
static BOOL boxDisabled;
////////////////////////////////////////////////////////////////////////////////////////////////////
-(instancetype)initWithClass:(Class)class
{
    if(self = [super init])
    {
        self.objClass = class;
    }
    return self;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(void)addArrayClassMap:(NSString*)propertyName class:(Class)classID
{
    if(!self.arrayMap)
        self.arrayMap = [[NSMutableDictionary alloc] init];
    [self.arrayMap setValue:classID forKey:propertyName];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(id)process:(id)object error:(NSError *__autoreleasing *)error
{
    if(!object)
        return nil;
    if([object isKindOfClass:[NSString class]])
    {
        NSData *data = [object dataUsingEncoding:NSUTF8StringEncoding];
        NSError* error = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if(error)
            return nil;
        return [self process:json error:&error];
    }
    else if([object isKindOfClass:[NSData class]])
    {
        NSError* error = nil;
        id json = [NSJSONSerialization JSONObjectWithData:object options:0 error:&error];
        if(error)
            return nil;
        return [self process:json error:&error];
    }
    else if([object isKindOfClass:[NSArray class]])
    {
        NSMutableArray* gather = [NSMutableArray arrayWithCapacity:[object count]];
        for(id child in object)
            [gather addObject:[self process:child error:error]];
        return gather;
    }
    if([object isKindOfClass:[NSDictionary class]])
    {
        NSDictionary* dict = object;
        NSArray* propArray = [self getPropertiesOfClass:self.objClass];
        id newObject = nil;
        if([[self.objClass class] respondsToSelector:@selector(newModel)])//for coreData support with DCModel
            newObject = objc_msgSend([self.objClass class], @selector(newModel));//[[self.objClass class] performSelector:@selector(newModel)];
        else
            newObject = [[self.objClass alloc] init];
        
        for(NSString* propName in propArray)
        {
            if([propName isEqualToString:@"objID"]) //special edge case for objective-c using the id keyword
            {
                if([self assignValue:@"id" propName:propName dict:dict obj:newObject error:error])
                    continue;
            }
            if([propName isEqualToString:@"objDescription"]) //special edge case for objective-c using the description method
            {
                if([self assignValue:@"description" propName:propName dict:dict obj:newObject error:error])
                    continue;
            }
            if([self assignValue:propName propName:propName dict:dict obj:newObject error:error])
            {
                continue;
            }
            NSString* objCName = [JSONJoy convertToJsonName:propName];
            [self assignValue:objCName propName:propName dict:dict obj:newObject error:error];
            if(isLoose)
            {
                NSString *looseName = [propName stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[propName substringToIndex:1] lowercaseString]];
                [self assignValue:looseName propName:propName dict:dict obj:newObject error:error];
            }
            if(error && *error)
                return nil;
        }
        return newObject;
    }
    return nil;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(BOOL)assignValue:(NSString*)key propName:(NSString*)propName dict:(NSDictionary*)dict obj:(id)obj error:(NSError**)error
{
    id value = dict[key];
    if(value)
    {
        if([[NSDate class] isSubclassOfClass:self.propertyClasses[propName]])
        {
            NSDate* date = [self formatDate:value];
            if(date)
                [obj setValue:date forKey:propName];
            return YES;
        }
        if([value isKindOfClass:[NSDictionary class]] && ![[obj valueForKey:propName] isKindOfClass:[NSDictionary class]])
        {
            NSError *childError = nil;
            id joy = [self.propertyClasses[propName] objectWithJoy:value error:&childError];
            if(childError && error)
            {
                *error = childError;
                return NO;
            }
            if(joy)
            {
                [obj setValue:joy forKey:propName];
                return YES;
            }
        }
        if([value isKindOfClass:[NSArray class]])
        {
            Class arrayClass = self.arrayMap[propName];
            NSArray *array = value;
            if(array.count > 0 && [array[0] isKindOfClass:[NSDictionary class]] && arrayClass)
            {
                NSMutableArray* gather = [NSMutableArray arrayWithCapacity:array.count];
                for(NSDictionary* dict in array)
                {
                    NSError *childError = nil;
                    id joy = [[JSONJoy JSONJoyWithClass:arrayClass] process:dict error:&childError];
                    if(joy && !childError)
                        [gather addObject:joy];
                    if(childError && error)
                    {
                        *error = childError;
                        return NO;
                    }
                }
                [obj setValue:gather forKey:propName];
                return YES;
            }
        }
        //this is a type check to ensure that the value is same type as expected.
        if(self.propertyClasses[propName] && ![value isKindOfClass:self.propertyClasses[propName]] && [NSNull null] != (NSNull*)value)
        {
            //special handling of BOOL type. It will auto box/convert a BOOL to a number or string if already set.
            if([value isKindOfClass:NSClassFromString(@"__NSCFBoolean")] && !boxDisabled)
            {
                if([self.propertyClasses[propName] isSubclassOfClass:[NSString class]])
                {
                    if([NSNull null] == (NSNull*)value)
                        [obj setValue:nil forKey:propName];
                    else
                        [obj setValue:[NSString stringWithFormat:@"%@",value] forKey:propName];
                    return YES;
                }
                else if([self.propertyClasses[propName] isSubclassOfClass:[NSNumber class]])
                {
                    if([NSNull null] == (NSNull*)value)
                        [obj setValue:nil forKey:propName];
                    else
                        [obj setValue:[NSNumber numberWithBool:(BOOL)value] forKey:propName];
                    return YES;
                }
            }
            NSString* errorString = [NSString stringWithFormat:@"%@. Value: %@ is of class type: %@ expected: %@",
                                     NSLocalizedString(@"Type does not match expected response", nil),propName,NSStringFromClass([value class]),self.propertyClasses[propName]];
            if(error)
                *error = [JSONJoy errorWithDetail:errorString code:JSONJoyErrorCodeIncorrectType];
            return NO;
        }
        if([NSNull null] == (NSNull*)value)
            [obj setValue:nil forKey:propName];
        else
            [obj setValue:value forKey:propName];
        return YES;
    }
    return NO;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
//gets all the properties names of the class
-(NSArray*)getPropertiesOfClass:(Class)objectClass
{
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(objectClass, &outCount);
    NSMutableArray *gather = [NSMutableArray arrayWithCapacity:outCount];
    for(i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        NSString* propName = [NSString stringWithUTF8String:property_getName(property)];
        const char *type = property_getAttributes(property);
        
        NSString *typeString = [NSString stringWithUTF8String:type];
        NSArray *attributes = [typeString componentsSeparatedByString:@","];
        NSString *typeAttribute = [attributes objectAtIndex:0];
        
        //may need to support these in the future.
        //NSString *propertyType = [typeAttribute substringFromIndex:1];
        //const char *rawPropertyType = [propertyType UTF8String];
        //if (strcmp(rawPropertyType, @encode(float)) == 0) //it's a float
        //else if (strcmp(rawPropertyType, @encode(int)) == 0)//it's an int
        //else if (strcmp(rawPropertyType, @encode(id)) == 0) //is id, so any NSObject
        
        if ([typeAttribute hasPrefix:@"T@"] && [typeAttribute length] > 3)
        {
            NSString * typeClassName = [typeAttribute substringWithRange:NSMakeRange(3, [typeAttribute length]-4)];  //turns @"NSDate" into NSDate
            Class typeClass = NSClassFromString(typeClassName);
            if(!self.propertyClasses)
                self.propertyClasses = [[NSMutableDictionary alloc] init];
            [self.propertyClasses setObject:typeClass forKey:propName];
        }
        [gather addObject:propName];
    }
    free(properties);
    if([objectClass superclass] && [objectClass superclass] != [NSObject class])
        [gather addObjectsFromArray:[self getPropertiesOfClass:[objectClass superclass]]];
    return gather;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
//converts some like avatarThumbUrl to avatar_thumb_url.
+(NSString*)convertToJsonName:(NSString*)propName
{
    return [self convertToJsonName:propName start:0];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(NSString*)convertToJsonName:(NSString*)propName start:(NSInteger)start
{
    NSRange range = [propName rangeOfString:@"[a-z.-][^a-z .-]" options:NSRegularExpressionSearch range:NSMakeRange(start, propName.length-start)];
    if(range.location != NSNotFound && range.location < propName.length)
    {
        unichar c = [propName characterAtIndex:range.location+1];
        propName = [propName stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%c",c]
                                                       withString:[[NSString stringWithFormat:@"_%c",c] lowercaseString]
                                                          options:0 range:NSMakeRange(start, propName.length-start)];
        return [self convertToJsonName:propName start:range.location+1];
    }
    return propName;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSDate*)formatDate:(NSString*)dateString
{
    if([NSNull null] == (NSNull*)dateString)
        return nil;
    if (dateString.length > 20)
    {
        dateString = [dateString stringByReplacingOccurrencesOfString:@":"
                                                           withString:@""
                                                              options:0
                                                                range:NSMakeRange(20, dateString.length-20)];
        NSRange range = [dateString rangeOfString:@"." options:NSBackwardsSearch];
        if(range.location == NSNotFound)
        {
            range = [dateString rangeOfString:@"+" options:NSBackwardsSearch];
            if(range.location == NSNotFound)
                range = [dateString rangeOfString:@"-" options:NSBackwardsSearch range:NSMakeRange(19, dateString.length-21)];
            if(range.location != NSNotFound)
            {
                NSString *save = [dateString substringFromIndex:range.location];
                dateString = [dateString substringToIndex:range.location];
                dateString = [dateString stringByAppendingFormat:@".000%@",save];
            }
            else
                dateString = [dateString stringByAppendingString:@".000+0000"];
        }
    }
    else
        dateString = [dateString stringByAppendingString:@".000+0000"];
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        //[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
    });
    return [dateFormatter dateFromString:dateString];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(instancetype)JSONJoyWithClass:(Class)class
{
    JSONJoy* mapper = [[JSONJoy alloc] initWithClass:class];
    return mapper;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(NSError*)errorWithDetail:(NSString*)detail code:(JSONJoyErrorCode)code
{
    NSMutableDictionary* details = [NSMutableDictionary dictionary];
    [details setValue:detail forKey:NSLocalizedDescriptionKey];
    return [[NSError alloc] initWithDomain:NSLocalizedString(@"JSONJoy", nil) code:code userInfo:details];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(void)setLoose:(BOOL)loose
{
    isLoose = !loose;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(void)setAutoConvertBOOLs:(BOOL)box
{
    boxDisabled = !box;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSArray*)propertyKeys
{
    return [self.propertyClasses allKeys];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
//just to silence the warnings
-(void)newModel
{
}
////////////////////////////////////////////////////////////////////////////////////////////////////

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation NSObject (JSONJoy)

////////////////////////////////////////////////////////////////////////////////////////////////////
+(JSONJoy*)jsonMapper
{
    return [[JSONJoy alloc] initWithClass:[self class]];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(id)objectWithJoy:(id)jsonObj
{
    return [self objectWithJoy:jsonObj error:nil];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
+(id)objectWithJoy:(id)jsonObj error:(NSError *__autoreleasing *)error
{
    JSONJoy* mapper = [self jsonMapper];
    return [mapper process:jsonObj error:error];
}
////////////////////////////////////////////////////////////////////////////////////////////////////

@end
