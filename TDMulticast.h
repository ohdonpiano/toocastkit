//
//  TDMulticast.h
//  toocastkit
//
//  Created by Daniele Poggi on 1/7/12.
//  Copyright (c) 2012 Toodev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TDMulticastConfig.h"
#import "TCPServer.h"

// NOTIFICATION CENTER NAMES
#define kTDMulticastDiscoverServicesFinished @"kTDMulticastDiscoverServicesFinished"

@interface TDMulticast : NSObject <TCPServerDelegate, NSNetServiceBrowserDelegate> {
        
    /**
     *	@brief	instance of TCPServer for Announce feature
     */
    TCPServer *_server;
    
    //DISCOVER
    
    NSString *_ownName;
	NSNetService *_ownEntry;
    
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
    NSNetService *_currentResolve;

}

@property (nonatomic, readonly) NSMutableArray *services;    

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
 *	@brief	Announce the app on the LAN with the device name
 */
- (void) announce;


/**
 *	@brief	Announce the app on the LAN with a specific name
 *
 *	@param 	shownName 	the name that will be seen by others
 */
- (void) announceWithName:(NSString*)shownName;

#pragma mark Discover

- (BOOL) discoverServices;

/**
 *	@brief	discover TDMulticast Announced servers on the LAN
 */
- (BOOL) discoverServicesWithIdentifier:(NSString*)identifier inDomain:(NSString *)domain;

@end
