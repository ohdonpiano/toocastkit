//
//  TDMulticast.m
//  toocastkit
//
//  Created by Daniele Poggi on 1/7/12.
//  Copyright (c) 2012 Toodev. All rights reserved.
//

#import "TDMulticast.h"
#import "TCPServer.h"
#import <netinet/in.h>
#import <sys/socket.h>

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
        
        outputStreamQueue = dispatch_queue_create("outputStreamQueue", NULL);
        
        _ownName = [[UIDevice currentDevice] name];
        _services = [[NSMutableArray alloc] init];
        
        inputStreams = [[NSMutableDictionary alloc] init];
        outputStreams = [[NSMutableDictionary alloc] init];
        
        outgoingQueues = [[NSMutableDictionary alloc] init];
    }
    return self;
}

static TDMulticast* INSTANCE;

+ (TDMulticast*) sharedInstance {
    if (nil == INSTANCE)
        INSTANCE = [[TDMulticast alloc] init];
    return INSTANCE;
}

#pragma mark - Utilities

#pragma mark - Announce/Conceal

#pragma mark Announce

- (void) announce {
    [self announceWithName:_ownName];
}

- (void) announceWithName:(NSString*)shownName {
    [self announceWithName:shownName port:kMulticastPost];
}

- (void) announceWithName:(NSString *)shownName port:(NSUInteger)port {
    
    if (nil != _server) {
        [_server stop];
        _server = nil;
    }
    
    _server = [[TCPServer alloc] init];
    _server.delegate = self;
    
    NSError *error = nil;
    if (![_server start:&error]) {
        NSLog(@"%s ERROR: %@",__PRETTY_FUNCTION__,error);
        return;
    }
    
    [_server enableBonjourWithDomain:kMulticastDomain applicationProtocol:[TCPServer bonjourTypeFromIdentifier:kMulticastIdentifier] name:shownName];
}

#pragma mark Conceal

- (void) conceal {
    [self concealWithName:_ownName];
}

- (void) concealWithName:(NSString*)shownName {
    
    if (nil != _server) {
        [_server stop];      
    }
}

#pragma mark - Discover

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
		
	}
    
    [self.services addObject:service];
    
	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
	if (!moreComing) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kTDMulticastDiscoverServicesFinished object:self userInfo:nil];
        
    }
}	

#pragma mark - Connect/Disconnect 

/*
 [stream close];
 [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
 [stream setDelegate:nil];
 */

- (void) connectWithService:(NSNetService*)service {
    
    NSLog(@"%s service name: %@",__PRETTY_FUNCTION__,service.name);
    
//    [service resolveWithTimeout:30.0];
    
    NSInputStream *inputStream = nil;
    NSOutputStream *outputStream = nil;
    if ([service getInputStream:&inputStream outputStream:&outputStream]) {
        
        [inputStreams setObject:inputStream forKey:service.name];
        [inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [inputStream setDelegate:self];
        [inputStream open];        
        
        [outputStreams setObject:outputStream forKey:service.name];
        [outputStream setDelegate:self];
        [outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [outputStream open];
        
    } else {
        NSLog(@"%s FATAL ERROR: streams not registered.",__PRETTY_FUNCTION__);
    }
}

#pragma mark - TCPServer delegate

- (void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name {
    NSLog(@"%s serviceName: %@",__PRETTY_FUNCTION__,name);
}

- (void) server:(TCPServer*)server didNotEnableBonjour:(NSDictionary *)errorDict {
    NSLog(@"%s",__PRETTY_FUNCTION__); 
}

- (void) didAcceptConnectionForServer:(TCPServer*)server inputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
    NSLog(@"%s registering streams with server name: %@",__PRETTY_FUNCTION__,server.name);
    
    // register input and output stream
    [inputStream setDelegate:self];
    [inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [inputStream open];
    [inputStreams setObject:inputStream forKey:server.name];
    
    [outputStream setDelegate:self];
    [outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [outputStream open];
    [outputStreams setObject:outputStream forKey:server.name];
}

#pragma mark - Send/Receive

#pragma mark Send

/**
 * Private method.
 * Presencts a common method for the various public sendElement methods.
 **/
- (void)sendElement:(NSDictionary *)element withTag:(long)tag
{
	NSAssert(dispatch_get_current_queue() == outputStreamQueue, @"Invoked on incorrect queue");
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kTDMulticastWillSendElement object:self userInfo:nil];
    
    // TODO: order peers by name, or with a defined order of some kind
    
    if ([outputStreams count] == 0)
        return;
    
    for (NSString *peerName in [outputStreams allKeys]) {
        
        NSOutputStream *outStream = [outputStreams objectForKey:peerName];
        
        if ([outStream hasSpaceAvailable]) {
    
            // send package
            NSString *errorStr = nil;
            NSData *outData = [NSPropertyListSerialization dataFromPropertyList:element format:NSPropertyListBinaryFormat_v1_0 errorDescription:&errorStr];
            
            const uint8_t *finalBuffer = [outData bytes];
            
            // send package
            int res = [outStream write:finalBuffer maxLength:[outData length]];
            
//            NSLog(@"%s packet sent: %u bytes", __PRETTY_FUNCTION__, [outData length]);
            
            if(res == -1 || res == 0) {
                // IGNORE
                NSLog(@"%s ERROR: write packet failed.",__PRETTY_FUNCTION__);
            }
            
        } else {
            
            NSMutableArray *outgoingQueue = [outgoingQueues objectForKey:peerName];
            if (nil == outgoingQueue) {
                outgoingQueue = [NSMutableArray array];
                [outgoingQueues setObject:outgoingQueue forKey:peerName];
            }
            [outgoingQueue insertObject:element atIndex:0];
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kTDMulticastDidSendElement object:self userInfo:nil];
}

- (void) sendDictionary:(NSDictionary*)dict {
    
    if ([outputStreams count] == 0)
        return;
    
    dispatch_block_t block = ^{
		
		@autoreleasepool
		{			
			[self sendElement:dict withTag:TAG_WRITE_STREAM];
		}
	};
	
	if (dispatch_get_current_queue() == outputStreamQueue)
		block();
	else
		dispatch_async(outputStreamQueue, block);
}

#pragma mark Receive

/* Use Notification Center, register kTDMulticastReceive*** signature family */

- (void) didReceiveElement:(NSDictionary*)element fromPeer:(NSString*)peerName {
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:peerName,@"peerName", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kTDMulticastDidReceiveElement object:element userInfo:userInfo];
}

#pragma mark - NSStream Delegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    
    if (nil != [aStream streamError]) {
        NSLog(@"%s status: %i - error: %@",__PRETTY_FUNCTION__,[aStream streamStatus],[aStream streamError]);
        return;
    }
    
    switch (eventCode) {
            
        case NSStreamEventOpenCompleted:
        {
        }
            break;
        case NSStreamEventHasSpaceAvailable:
        {
            
            // GOAL: find the correct outgoing queue for this stream
            
            NSString *peerName = nil;
            
            for (NSString *aPeerName in [outputStreams allKeys]) {
                NSStream *oStream = [outputStreams objectForKey:aPeerName];
                if (aStream == oStream) {
                    peerName = aPeerName;
                    break;
                }
            }
            
            // ILLEGAL PEER NAME
            // cannot accept an element from an unknown peer. discard
            
            if (peerName == nil) {
                return;
            }
            
            NSMutableArray *outgoingQueue = [outgoingQueues objectForKey:peerName];
            
            if ([outgoingQueue count] > 0) {
                NSDictionary *element = [outgoingQueue objectAtIndex:[outgoingQueue count]-1];
                [self sendDictionary:element];
                [outgoingQueue removeObjectAtIndex:[outgoingQueue count]-1];
            }
            
        }
            break;
        case NSStreamEventHasBytesAvailable:
        {
//            NSLog(@"%s NSStreamEventHasBytesAvailable",__PRETTY_FUNCTION__);
            
            NSString *peerName = nil;
            
            for (NSString *aPeerName in [inputStreams allKeys]) {
                NSStream *iStream = [inputStreams objectForKey:aPeerName];
                if (aStream == iStream) {
                    peerName = aPeerName;
                    break;
                }
            }
            
            // ILLEGAL PEER NAME
            // cannot accept an element from an unknown peer. discard
            
            if (peerName == nil) {
                return;
            }
            
            uint8_t buf[kMaxInputDataBuffer];
            unsigned int len = 0;
            len = [(NSInputStream*)aStream read:buf maxLength:kMaxInputDataBuffer];
            if(len > 0) {
                // wrapping buffer content inside NSData
                NSData *packet = [NSData dataWithBytes:buf length:len];
                // use network input entry point
                
                NSString *errorStr = nil;
                NSPropertyListFormat format;
                NSDictionary *element = [NSPropertyListSerialization propertyListFromData:packet mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&errorStr];     
                
                if (nil != element)
                    [self didReceiveElement:element fromPeer:peerName];
                else
                    NSLog(@"%s NSStreamEventHasBytesAvailable ERROR: %@", __PRETTY_FUNCTION__, errorStr);
            }
             
        }
            break;
        case NSStreamEventEndEncountered:
        {
        }
            break;
        case NSStreamEventErrorOccurred:
        {
        }
            break;
        default:
            break;
    }
}

#pragma mark - NSNetService Delegate


/* Sent to the NSNetService instance's delegate prior to advertising the service on the network. If for some reason the service cannot be published, the delegate will not receive this message, and an error will be delivered to the delegate via the delegate's -netService:didNotPublish: method.
 */
- (void)netServiceWillPublish:(NSNetService *)sender {
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

/* Sent to the NSNetService instance's delegate when the publication of the instance is complete and successful.
 */
- (void)netServiceDidPublish:(NSNetService *)sender {
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

/* Sent to the NSNetService instance's delegate when an error in publishing the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants). It is possible for an error to occur after a successful publication.
 */
- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

/* Sent to the NSNetService instance's delegate prior to resolving a service on the network. If for some reason the resolution cannot occur, the delegate will not receive this message, and an error will be delivered to the delegate via the delegate's -netService:didNotResolve: method.
 */
- (void)netServiceWillResolve:(NSNetService *)sender {
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

/* Sent to the NSNetService instance's delegate when one or more addresses have been resolved for an NSNetService instance. Some NSNetService methods will return different results before and after a successful resolution. An NSNetService instance may get resolved more than once; truly robust clients may wish to resolve again after an error, or to resolve more than once.
 */
- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    NSLog(@"%s",__PRETTY_FUNCTION__);
    
    [self stopCurrentResolve];
}

/* Sent to the NSNetService instance's delegate when an error in resolving the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants).
 */
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    NSLog(@"%s",__PRETTY_FUNCTION__);
    
    [self stopCurrentResolve];
}

/* Sent to the NSNetService instance's delegate when the instance's previously running publication or resolution request has stopped.
 */
- (void)netServiceDidStop:(NSNetService *)sender {
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

/* Sent to the NSNetService instance's delegate when the instance is being monitored and the instance's TXT record has been updated. The new record is contained in the data parameter.
 */
- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data {
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

@end
