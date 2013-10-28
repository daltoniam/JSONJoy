////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  JSONJoy.m
//
//  Created by Dalton Cherry on 10/23/13.
//
////////////////////////////////////////////////////////////////////////////////////////////////////

#import "JSONJoy.h"
#import <objc/runtime.h>

@interface JSONJoy ()

@property(nonatomic,assign)Class objClass;
@property(nonatomic,strong)NSMutableDictionary* arrayMap;
@property(nonatomic,strong)NSMutableDictionary* propertyClasses;

@end

@implementation JSONJoy

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
-(id)process:(id)object
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
        return [self process:json];
    }
    else if([object isKindOfClass:[NSData class]])
    {
        NSError* error = nil;
        id json = [NSJSONSerialization JSONObjectWithData:object options:0 error:&error];
        if(error)
            return nil;
        return [self process:json];
    }
    else if([object isKindOfClass:[NSArray class]])
    {
        NSMutableArray* gather = [NSMutableArray arrayWithCapacity:[object count]];
        for(id child in object)
            [gather addObject:[self process:child]];
        return gather;
    }
    if([object isKindOfClass:[NSDictionary class]])
    {
        NSDictionary* dict = object;
        NSArray* propArray = [self getPropertiesOfClass:self.objClass];
        id newObject = nil;
        if([[self.objClass class] respondsToSelector:@selector(newObject)])  //[self.objClass resolveClassMethod:@selector(newObject)] //for coreData support with DCModel
            newObject = [[self.objClass class] performSelector:@selector(newObject)];
        else
            newObject = [[self.objClass alloc] init];
        
        for(NSString* propName in propArray)
        {
            if([propName isEqualToString:@"objID"]) //special edge case for objective-c using the id keyword
            {
                if([self assignValue:@"id" propName:propName dict:dict obj:newObject])
                    continue;
            }
            if([self assignValue:propName propName:propName dict:dict obj:newObject])
            {
                continue;
            }
            NSString* objCName = [JSONJoy convertToJsonName:propName];
            [self assignValue:objCName propName:propName dict:dict obj:newObject];
        }
        return newObject;
    }
    return nil;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(BOOL)assignValue:(NSString*)key propName:(NSString*)propName dict:(NSDictionary*)dict obj:(id)obj
{
    id value = dict[key];
    if(value)
    {
        if([self.propertyClasses[propName] isKindOfClass:[NSDate class]])
        {
            NSDate* date = [self formatDate:value];
            if(date)
                [obj setValue:date forKey:propName];
            return YES;
        }
        if([value isKindOfClass:[NSDictionary class]] && ![[obj valueForKey:propName] isKindOfClass:[NSDictionary class]])
        {
            id joy = [value objectWithJoy:obj];
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
                    id joy = [[JSONJoy JSONJoyWithClass:arrayClass] process:dict];
                    if(joy)
                        [gather addObject:joy];
                }
                [obj setValue:gather forKey:propName];
                return YES;
            }
        }
        //this is a type check to ensure that the value is same type as expected.
        if([NSNull null] != (NSNull*)value && [value isKindOfClass:self.propertyClasses[propName]])
            return NO;
        
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
    NSMutableArray* gather = [NSMutableArray arrayWithCapacity:outCount];
    for(i = 0; i < outCount; i++)
    {
        objc_property_t property = properties[i];
        NSString* propName = [NSString stringWithUTF8String:property_getName(property)];
        const char * type = property_getAttributes(property);
        
        NSString * typeString = [NSString stringWithUTF8String:type];
        NSArray * attributes = [typeString componentsSeparatedByString:@","];
        NSString * typeAttribute = [attributes objectAtIndex:0];
        
        if ([typeAttribute hasPrefix:@"T@"] && [typeAttribute length] > 1)
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
+(NSString*)convertToJsonName:(NSString*)propName start:(int)start
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
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        //[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.000Z"];
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

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation NSObject (JSONJoy)

+(id)objectWithJoy:(id)jsonObj
{
    JSONJoy* mapper = [[JSONJoy alloc] initWithClass:[self class]];
    return [mapper process:jsonObj];
}

@end
