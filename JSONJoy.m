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
        id newObject = [[self.objClass alloc] init];
        for(NSString* propName in propArray)
        {
            if([propName isEqualToString:@"objectID"]) //special edge case for objective-c using the id keyword
            {
                if([self assignValue:@"id" propName:propName dict:dict obj:newObject])
                    continue;
            }
            if([self assignValue:propName propName:propName dict:dict obj:newObject])
            {
                continue;
            }
            NSString* objCName = [self convertToJsonName:propName];
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
        [gather addObject:propName];
    }
    free(properties);
    if([objectClass superclass] && [objectClass superclass] != [NSObject class])
        [gather addObjectsFromArray:[self getPropertiesOfClass:[objectClass superclass]]];
    return gather;
}
////////////////////////////////////////////////////////////////////////////////////////////////////
//converts some like avatarThumbUrl to avatar_thumb_url.
-(NSString*)convertToJsonName:(NSString*)propName
{
    return [self convertToJsonName:propName start:0];
}
////////////////////////////////////////////////////////////////////////////////////////////////////
-(NSString*)convertToJsonName:(NSString*)propName start:(int)start
{
    NSRange range = [propName rangeOfString:@"[a-z.-][^a-z .-]" options:NSRegularExpressionSearch range:NSMakeRange(start, propName.length-start)];
    if(range.location != NSNotFound && range.location < propName.length)
    {
        unichar c = [propName characterAtIndex:range.location+1];
        propName = [propName stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%c",c]
                                                       withString:[[NSString stringWithFormat:@"_%c",c] lowercaseString]                                                          options:0 range:NSMakeRange(start, propName.length-start)];
        return [self convertToJsonName:propName start:range.location+1];
    }
    return propName;
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
