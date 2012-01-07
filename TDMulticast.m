//
//  TDMulticast.m
//  toocastkit
//
//  Created by Daniele Poggi on 1/7/12.
//  Copyright (c) 2012 Toodev. All rights reserved.
//

#import "TDMulticast.h"
#import "TCPServer.h"

@implementation TDMulticast

#pragma mark Kit Entry Point

- (id)init {
    self = [super init];
    if (self) {
        _server = [[TCPServer alloc] init];
        _server.delegate = self;
        
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

- (void) announceWithAppName:(NSString*)appName serviceName:(NSString*)serviceName {
    [_server enableBonjourWithDomain:nil applicationProtocol:appName name:serviceName];
    NSError *error = nil;
    if (![_server start:&error]) {
        NSLog(@"%s ERROR: %@",__PRETTY_FUNCTION__,error);
    }
}

- (void) discover

#pragma mark - TCPServer delegate

- (void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name {
    
}
- (void) server:(TCPServer*)server didNotEnableBonjour:(NSDictionary *)errorDict {
    
}
- (void) didAcceptConnectionForServer:(TCPServer*)server inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr {
    
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
		[self sortAndUpdateUI];
	}
}	

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
    
	// If a service came online, add it to the list and update the table view if no more events are queued.
	if (!service) {
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
		[self sortAndUpdateUI];
	}
}	

// This should never be called, since we resolve with a timeout of 0.0, which means indefinite
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
	[self stopCurrentResolve];
	[self.tableView reloadData];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
	assert(service == self.currentResolve);
	
	[service retain];
	[self stopCurrentResolve];
	
	[self.delegate browserViewController:self didResolveInstance:service];
	[service release];
}

- (void)cancelAction {
	[self.delegate browserViewController:self didResolveInstance:nil];
}

@end
