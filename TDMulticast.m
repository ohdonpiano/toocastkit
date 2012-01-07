//
//  TDMulticast.m
//  toocastkit
//
//  Created by Daniele Poggi on 1/7/12.
//  Copyright (c) 2012 Toodev. All rights reserved.
//

#import "TDMulticast.h"
#import "TCPServer.h"

@interface TDMulticast()
@property (nonatomic, retain, readwrite) NSNetService *ownEntry;
@property (nonatomic, retain, readwrite) NSNetServiceBrowser *netServiceBrowser;
@property (nonatomic, retain, readwrite) NSNetService *currentResolve;
@property (nonatomic, retain, readwrite) NSTimer *timer;
@property (nonatomic, assign, readwrite) BOOL needsActivityIndicator;
@property (nonatomic, assign, readwrite) BOOL initialWaitOver;

- (void)stopCurrentResolve;

@end

@implementation TDMulticast

@synthesize ownEntry = _ownEntry;
@synthesize currentResolve = _currentResolve;
@synthesize netServiceBrowser = _netServiceBrowser;
@synthesize services = _services;
@synthesize needsActivityIndicator = _needsActivityIndicator;
@dynamic timer;
@synthesize initialWaitOver = _initialWaitOver;

#pragma mark Kit Entry Point

- (id)init {
    self = [super init];
    if (self) {
        _server = [[TCPServer alloc] init];
        _server.delegate = self;
        
        _ownName = [[UIDevice currentDevice] name];
        _services = [[NSMutableArray alloc] init];
    }
    return self;
}

static TDMulticast* INSTANCE;

+ (TDMulticast*) sharedInstance {
    if (nil == INSTANCE)
        INSTANCE = [[TDMulticast alloc] init];
    return INSTANCE;
}

#pragma mark Utilities

#pragma mark Announce

- (void) announce {
    [self announceWithName:_ownName];
}

- (void) announceWithName:(NSString*)shownName; {
    [_server enableBonjourWithDomain:kMulticastDomain applicationProtocol:[TCPServer bonjourTypeFromIdentifier:kMulticastIdentifier] name:shownName];
    NSError *error = nil;
    if (![_server start:&error]) {
        NSLog(@"%s ERROR: %@",__PRETTY_FUNCTION__,error);
    }
}

#pragma mark Discover

- (void)stopCurrentResolve {
	[self.currentResolve stop];
	self.currentResolve = nil;
}

- (BOOL) discoverServices {
    return [self discoverServicesWithIdentifier:kMulticastIdentifier inDomain:kMulticastDomain];
}

// Creates an NSNetServiceBrowser that searches for services of a particular type in a particular domain.
// If a service is currently being resolved, stop resolving it and stop the service browser from
// discovering other services.
- (BOOL) discoverServicesWithIdentifier:(NSString*)identifier inDomain:(NSString *)domain {
	
	// cleaning code
	[self stopCurrentResolve];
	[self.netServiceBrowser stop];
	[self.services removeAllObjects];
    
	self.netServiceBrowser = [[NSNetServiceBrowser alloc] init];    
	_netServiceBrowser.delegate = self;
	[self.netServiceBrowser searchForServicesOfType:[TCPServer bonjourTypeFromIdentifier:identifier] inDomain:domain];
	return YES;
}

#pragma mark - TCPServer delegate

- (void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name {
    NSLog(@"%s serviceName: %@",__PRETTY_FUNCTION__,name);
}
- (void) server:(TCPServer*)server didNotEnableBonjour:(NSDictionary *)errorDict {
    NSLog(@"%s",__PRETTY_FUNCTION__); 
}
- (void) didAcceptConnectionForServer:(TCPServer*)server inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr {
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

#pragma mark NetServiceBrowser Delegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing {
	// If a service went away, stop resolving it if it's currently being resolved,
	// remove it from the list and update the table view if no more events are queued.
	
	if (self.currentResolve && [service isEqual:self.currentResolve]) {
		[self stopCurrentResolve];
	}
	[self.services removeObject:service];
	if (self.ownEntry == service)
		self.ownEntry = nil;
	
	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
	if (!moreComing) {
		[[NSNotificationCenter defaultCenter] postNotificationName:kTDMulticastDiscoverServicesFinished object:self userInfo:nil];
	}
}	

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
    
	// If a service came online, add it to the list and update the table view if no more events are queued.
	if (nil == service) {
		return;
	}
	NSRange range;
	@try {
		range = [service.name rangeOfString:_ownName];
	} @catch (NSException *ex) {
		range = [service.name rangeOfString:[[UIDevice currentDevice] name]];
	}
	if (NSNotFound != range.location) {
		self.ownEntry = service;
	} else {
		[self.services addObject:service];
	}
	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
	if (!moreComing) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kTDMulticastDiscoverServicesFinished object:self userInfo:nil];
	
    }
}	

// This should never be called, since we resolve with a timeout of 0.0, which means indefinite
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
	[self stopCurrentResolve];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
	assert(service == self.currentResolve);
	
	[self stopCurrentResolve];
	
//	[self.delegate browserViewController:self didResolveInstance:service];
}

- (void)cancelAction {
	
}

@end
