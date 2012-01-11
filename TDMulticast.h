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

#define kMaxInputDataBuffer 2048 // 2 KB

// Define the various tags we'll use to differentiate what it is we're currently reading or writing
#define TAG_READ_START         100
#define TAG_READ_STREAM        101
#define TAG_WRITE_START        200
#define TAG_WRITE_STREAM       201
#define TAG_WRITE_RECEIPT      202

// NOTIFICATION CENTER NAMES
#define kTDMulticastDiscoverServicesFinished @"kTDMulticastDiscoverServicesFinished"

// Will send element
#define kTDMulticastWillSendElement @"kTDMulticastWillSendElement"
// Did send element
#define kTDMulticastDidSendElement @"kTDMulticastDidSendElement"

// Did receive element
#define kTDMulticastDidReceiveElement @"kTDMulticastDidReceiveElement"

@interface TDMulticast : NSObject <TCPServerDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate, NSStreamDelegate> {
    
    // ANNOUNCE
    
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
    
    // SEND
    
    dispatch_queue_t outputStreamQueue;
    
    /**
     *	@brief	collection of input streams. the key of the dictionary is the name of the service
     * the value is then the associated input stream
     */
    NSMutableDictionary *inputStreams;
    
    /**
     *	@brief	collection of output streams. the key of the dictionary is the name of the service
     * the value is then the associated output stream
     */
    NSMutableDictionary *outputStreams;
    
    /**
     *	@brief	collection of outgoing queues. the key is the name of the peer name, the value
     *  is the mutable array of packets to send on the stream.
     */
    NSMutableDictionary *outgoingQueues;

        
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

#pragma mark - Announce/Conceal

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

- (void) announceWithName:(NSString *)shownName port:(NSUInteger)port;

#pragma mark Conceal

- (void) conceal;

- (void) concealWithName:(NSString*)shownName;

#pragma mark Discover

- (BOOL) discoverServices;

/**
 *	@brief	discover TDMulticast Announced servers on the LAN
 */
- (BOOL) discoverServicesWithIdentifier:(NSString*)identifier inDomain:(NSString *)domain;

#pragma mark - Connect/Disconnect

- (void) connectWithService:(NSNetService*)service;

#pragma mark - Send/Receive

#pragma mark Send

- (void) sendDictionary:(NSDictionary*)dict;

#pragma mark Receive

/* Use Notification Center, register kTDMulticastReceive*** signature family */

- (void) didReceiveElement:(NSDictionary*)element fromPeer:(NSString*)peerName;

@end
