//
//  TDMulticast.h
//  toocastkit
//
//  Created by Daniele Poggi on 1/7/12.
//  Copyright (c) 2012 Toodev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCPServer.h"

@interface TDMulticast : NSObject <TCPServerDelegate> {
        
    /**
     *	@brief	instance of TCPServer for Announce feature
     */
    TCPServer *_server;
    
    //DISCOVER
    
    /**
     *	@brief	the array of discovered services
     */
    NSMutableArray *_services;    
    
    /**
     *	@brief	browser for net services
     */
    NSNetServiceBrowser *_netServiceBrowser;
    
	/**
     *	@brief	current discovered net service
     */
    NSNetService *_netService;

}

#pragma mark Kit Entry Point

/**
 *	@brief	SINGLETON GETTER
 *
 *	@return	the shared instance of TDMulticast
 */
+ (TDMulticast*) sharedInstance;

#pragma mark - Utilities

#pragma mark Announce

/**
 *	@brief	Announce the app on the LAN with a service to offer
 *
 *	@param 	appName 	the application name, e.g. "TooConsole"
 *	@param 	serviceName 	the service name, e.g. "consoleShare"
 */
- (void) announceWithAppName:(NSString*)appName serviceName:(NSString*)serviceName;

#pragma mark Discover

/**
 *	@brief	discover TDMulticast Announced servers on the LAN
 */
- (void) discoverOverLAN;


@end
