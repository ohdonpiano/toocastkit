//
//  TDMulticastConfig.h
//  TooConsole
//
//  Created by Daniele Poggi on 1/7/12.
//  Copyright (c) 2012 Toodev. All rights reserved.
//

// this identifier is needed to specify uniquely the Application over the LAN
// change it as you like, for example com.mycompany.myserviceid

#define kMulticastIdentifier @"serviceIdentifier"

// this is the port that the service will use. change it as you like.
// you should consider to search for an unused port number here:

#define kMulticastPost 10000

// the default domain

#define kMulticastDomain @"local"
