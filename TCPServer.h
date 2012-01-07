//File: TCPServer.h
//Abstract: A TCP server
//Version: 1.7
//Created by Daniele Poggi on 1/7/12.
//Copyright (c) 2012 Toodev. All rights reserved.

#import <Foundation/Foundation.h>

@class TCPServer;

NSString * const TCPServerErrorDomain;

typedef enum {
    kTCPServerCouldNotBindToIPv4Address = 1,
    kTCPServerCouldNotBindToIPv6Address = 2,
    kTCPServerNoSocketsAvailable = 3,
} TCPServerErrorCode;


@protocol TCPServerDelegate <NSObject>
@optional
- (void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name;
- (void) server:(TCPServer*)server didNotEnableBonjour:(NSDictionary *)errorDict;
- (void) didAcceptConnectionForServer:(TCPServer*)server inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr;
@end


@interface TCPServer : NSObject <NSNetServiceDelegate> {
			
	NSNetService* _netService;
	
@private
	id _delegate;
    uint16_t _port;
	CFSocketRef _ipv4socket;	
}

@property(nonatomic,retain) NSNetService* netService;

- (NSString*) name;
- (BOOL)start:(NSError **)error;
- (BOOL)stop;
- (BOOL) enableBonjourWithDomain:(NSString*)domain applicationProtocol:(NSString*)protocol name:(NSString*)name; //Pass "nil" for the default local domain - Pass only the application protocol for "protocol" e.g. "myApp"

@property(nonatomic,retain) id<TCPServerDelegate> delegate;

+ (NSString*) bonjourTypeFromIdentifier:(NSString*)identifier;

@end
