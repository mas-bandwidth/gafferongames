+++
categories = ["Building a Game Network Protocol"]
tags = ["networking"]
date = "2016-09-28"
title = "Client Server Connection"
description = "How to create a client/server connection over UDP"
draft = false
+++

## Introduction

Hi, I'm [Glenn Fiedler](/about) and welcome to **[Building a Game Network Protocol](/categories/building-a-game-network-protocol/)**.

In this article we're going to build a client/server connection on top of UDP.

And I can almost guarantee you at this point that some people have decided not to read this article because I'm obviously a fool. I mean, who could possibly justify all the effort required to build a completely custom client/server network protocol on top of UDP, when, for so many people, TCP is simply good enough? Check out this clown! Obviously you should just use TCP, or _(insert some other protocol that happens to be built on top of UDP anyway)_. Sigh.

Why is it in 2016 that discussions about UDP vs. TCP are still so controversial, why is it that pages of uninformed comments spring up on Hacker News with each post I make about UDP-based protocols, posts written about the best practices I've learned over 10 years working in the game industry as a network programmer? I'm not mad, just frustrated, and honestly kind of perplexed! Why does this topic bring out such strong reactions in people?

Why is this even a point for discussion, when it's been a solved problem in the game industry for at least 20 years, when most fast paced games, and virtually _all_ first person shooters are networked using UDP?

* Counterstrike
* Call of Duty
* Titanfall
* Halo
* Battlefront
* Overwatch

All of these games. Every. Single. One. Is networked with a custom client/server network protocol built on top of UDP. This is the established best practice in the industry because it gets the best result. If you're making a first person shooter and you're networking it with TCP, you're making a mistake. Simple as that.

So while TCP is useful in some many contexts, in the context of fast paced action games played over the internet, it's all UDP, baby. Before we get down to the gritty details of implementing one of these protocols, let's spend a bit of time exploring why this is.

## Why First Person Shooters Use UDP

First person shooters are different to web servers[*](#quic_footnote).

First person shooters send **time critical data**.

This data includes player inputs sent from client to server, and the state of the world sent from the server to clients. If this data arrives late, it is _utterly useless_ and is thrown away. The client has no use for the state of the world 1/4 of a second ago, just like the server has no use for player input from the past.

So, why can't we use TCP for time critical data? The answer is that TCP delivers data reliably and in-order, and to do this on top of IP, which is unreliable and unordered, it holds more recent packets *(that we want)* hostage in a queue while older packets *(that we don't!)* are resent over the network. 

This is known as **head of line blocking** and it's a huge problem for time critical data. To understand why, consider a game server broadcasting the state of the world to clients 10 times per-second. Each client advances time forward and wants to display the most recent state it has received from the server.

<img src="/img/network-protocol/client-time.png" width="100%"/>

But if the packet containing state for time t = 10.0 is lost, under TCP we must wait for it to be resent before we can access t = 10.1 and 10.2, even though those packets have already arrived and contain the state the client wants to show. Worse still, by the time the resent packet arrives, it's far too late for the client to actually do anything useful with it. The client has already advanced past 10.0 and wants to display something around 10.3 or 10.4!

So why resend dropped packets at all? **BINGO!** What we'd really like is an option to tell TCP: "Hey, I don't care about old packets being resent, by they time they arrive I can't use them anyway, so just let me skip over them and access the most recent data". But TCP simply does not give us this option. All data must be delivered reliably and in-order.

This creates terrible problems for time critical data where packet loss *and* latency exist. Situations like, you know, The Internet, where people play FPS games. Large hitches corresponding to multiples of round trip time are added to the stream of data as TCP waits for dropped packets to be resent, which means additional buffering to smooth out these hitches, adding even more latency, or long pauses where the game freezes and is non-responsive.

Neither option is acceptable for first person shooters, which is why virtually all first person shooters are networked using UDP. UDP doesn't provide any reliability or ordering, so protocols built on top of UDP can access the most recent data without waiting for lost packets to be resent, and implement whatever reliability they need in radically different ways to TCP.

But, using UDP comes at a cost: 

**UDP doesn't provide any concept of connection.**

We have to build that ourselves. This is a lot of work! So strap in, get ready, because we're going to build it all up from scratch using same basic techniques first person shooters use when creating their protocols over UDP. I know, I've worked on a few. You can use this client/server protocol for games or non-gaming applications and, provided the data you send is time critical, I promise you, it's well worth the effort.

<a name="quic_footnote"></a> _\* These days even web servers are transitioning to UDP via [Google's QUIC](https://ma.ttias.be/googles-quic-protocol-moving-web-tcp-udp/). If you still think TCP is good enough for time critical data in 2016, I encourage you to put that in your pipe and smoke it :)_

## What We're Building

The goal is to create an abstraction on top of a UDP socket where our server presents a number of _virtual slots_ for clients to connect to:

<img src="/img/network-protocol/connection-request.png" width="100%"/>

When a client requests a connection, it gets assigned to one of these slots:

<img src="/img/network-protocol/connection-accepted.png" width="100%"/>

If a client requests connection, but no slots are available, the server is full and the connection request is denied:

<img src="/img/network-protocol/server-is-full.png" width="100%"/>

Once a client is connected, packets are exchanged in both directions. These packets form the basis for the custom protocol between the client and server which is game specific.

<img src="/img/network-protocol/client-server-packets.png" width="100%"/>

In a first person shooter, packets are sent continuously in both directions. Clients send input to the server as quickly as possible, often 30 or 60 times per-second, and the server broadcasts the state of the world to clients 10, 20 or even 60 times per-second.

Because of this steady flow of packets in both directions there is no need for keep-alive packets. If at any point packets stop being received from the other side, the connection simply times out. No packets for 5 seconds is a good timeout value in my opinion, but you can be more aggressive if you want. 

When a client slot times out on the server, it becomes available for other clients to connect. When the client times out, it transitions to an error state.

## Simple Connection Protocol

Let's get started with the implementation of a simple protocol. It's a bit basic and a more than a bit naive, but it's a good starting point and we'll build on it.

First up we have the client state machine. 

The client is in one of three states:

* Disconnected
* Connecting
* Connected

Initially the client starts in **disconnected**, and is told to connect to a server with a particular IP address and port. At this point the client transitions to the **connecting** state and sends <u>_connection request_</u> packets to the server. 

They look something like this:

<img src="/img/network-protocol/connection-request-packet.png" width="100%"/>

The CRC32 and implicit protocol id in the packet header allow the server to trivially reject UDP packets not belonging to this protocol or from a different version of it. For details, please see [Reading and Writing Packets](http://gafferongames.com/building-a-game-network-protocol/reading-and-writing-packets/) and [Serialization Strategies](http://gafferongames.com/building-a-game-network-protocol/serialization-strategies/).

Since connection request packets are sent over UDP, they may be lost, received in duplicate, or out of order. Because of this we do two things: 1) we keep sending packets for the client state until we get a response from the server, or the client times out, and 2) on both client and server we ignore any packets that don't correspond to what we are expecting, since a lot of redundant packets are flying over the network.

On the server, we have the following data structure:

        const int MaxClients = 64;

        class Server
        {
            int m_maxClients;
            int m_numConnectedClients;
            bool m_clientConnected[MaxClients];
            Address m_clientAddress[MaxClients];
        };

Which lets the server lookup a free slot for a client to join (if any are free):

        int Server::FindFreeClientIndex() const
        {
            for ( int i = 0; i < m_maxClients; ++i )
            {
                if ( !m_clientConnected[i] )
                    return i;
            }
            return -1;
        }

Find the client index corresponding to an IP address and port:

        int Server::FindExistingClientIndex( const Address & address ) const
        {
            for ( int i = 0; i < m_maxClients; ++i )
            {
                if ( m_clientConnected[i] && m_clientAddress[i] == address )
                    return i;
            }
            return -1;
        }

Check if a client is connected to a given slot:

        bool Server::IsClientConnected( int clientIndex ) const
        {
            return m_clientConnected[clientIndex];
        }

and retrieve a client’s IP address and port by client index:

        const Address & Server::GetClientAddress( int clientIndex ) const
        {
            return m_clientAddress[clientIndex];
        }

Using these queries we can implement the following logic when a <u>_connection request_</u> packet is received on the server:

* If the server is full, reply with <u>_connection denied: server is full_</u>.

* If the sender corresponds to the address of a client that is already connected, reply with <u>_connection accepted_</u>. This is necessary because the first response may not have gotten through. If we don't resend this response, the client gets stuck in the **connecting** state until it times out.

* Otherwise, this connection request is from a new client and we have a slot free. Assign the client to the free slot and respond with <u>_connection accepted_</u>.

The connection accepted packet tells the client which client index it was assigned, which the client needs to know which player it is in the game:

<img src="/img/network-protocol/connection-accepted-packet.png" width="100%"/>

Once the server sends a connection accepted packet, from its point of view it considers that client connected. As the server ticks forward, it watches connected client slots, and if no packets have been received from that client for 5 seconds, the slot times out and is reset, ready for another client to connect.

Back on the client, while in the **connecting** state the client listens for <u>_connection denied_</u> and <u>_connection accepted_</u> packets from the server. Any other packets are ignored. If the client receives <u>_connection accepted_</u>, it transitions to **connected**. If it receives <u>_connection denied_</u>, or after 5 seconds hasn't received any response from the server, it transitions to **disconnected**.

Once the client hits **connected** it starts sending connection payload packets to the server. If no packets are received from the server in 5 seconds, the client times out and transitions to **disconnected**.

## Weaknesses of the Simple Connection Protocol

While this protocol is easy to implement, we can't use a protocol like this in production. It's way too naive. It simply has too many weaknesses to be taken seriously:

* Spoofed packet source addresses can be used to redirect connection accepted responses to a target (victim) address. If the connection accepted packet is larger than the connection request packet, attackers can use this protocol as part of a [DDoS amplification attack](https://www.us-cert.gov/ncas/alerts/TA14-017A).

* Spoofed packet source addresses can be used to trivially fill all client slots on a server by sending connection request packets from n different IP addresses, where n is the number of clients allowed per-server. This is a real problem for dedicated servers. Obviously you want to make sure that only real clients are filling slots on servers you are paying for.

* An attacker can trivially fill all slots on a server by varying the client UDP port number on each client connection. This is because clients are considered unique on an address + port basis. This isn't easy to fix because due to NAT (network address translation), different players behind the same router collapse to the same IP address with only the port being different.

* Traffic between the client and server can be read and modified in transit by a third party. While the CRC32 protects against packet corruption, an attacker would simply recalculate the CRC32 to match the modified packet.

* If an attacker knows the client and server IP addresses and ports, they can impersonate the client or server. This gives an attacker the power to completely a hijack a client’s connection and perform actions on their behalf.

* Once a client is connected to a server there is no way for them to disconnect cleanly, they can only time out. This creates a delay before the server realizes a client has disconnected, or before a client realizes the server has shut down. It would be nice if both the client and server could indicate a clean disconnect, so the other side doesn’t need to wait for timeout in the common case.

* Clean disconnection is usually implemented with a disconnect packet, however because an attacker can impersonate the client and server with spoofed packets, doing so would give the attacker the ability to disconnect a client from the server whenever they like, provided they know the client and server IP addresses and the structure of the disconnect packet.

* If a client disconnects dirty and attempts to reconnect before their slot times out on the server, the server still thinks that client is connected and replies with <u>_connection accepted_</u> to handle packet loss. The client processes this response and thinks it's connected to the server, but it's actually in an undefined state.

While some of these problems require authentication and encryption before they can be fully solved, we can make some small steps forward to improve the protocol before we get to that. These changes are instructive.

## Improving The Connection Protocol

The first thing we want to do is only allow clients to connect if they can prove they are actually at the IP address and port they say they are.

To do this, we no longer accept client connections immediately on connection request, instead we send back a challenge packet, and only complete connection when a client replies with information that can only be obtained from that challenge packet.

The sequence of operations in a typical connect now looks like this:

<img src="/img/network-protocol/challenge-response.png" width="100%"/>

To implement this we need an additional data structure on the server. Somewhere to store the challenge data for pending connections, so when a challenge response comes in from a client we can check against the corresponding entry in the data structure and make sure it's a valid response to the challenge sent to that address.

While the pending connect data structure can be made larger than the maximum number of connected clients, it's still ultimately finite and is therefore subject to attack. We'll cover some defenses against this in the next article. But for the moment, be happy at least that attackers can't progress to the **connected** state with spoofed packet source addresses.

Next, to guard against our protocol being used in a DDoS amplification attack, we'll inflate client to server packets so they're large relative to the response packet sent from the server. This means we add padding to both <u>_connection request_</u> and <u>_challenge response_</u> packets and enforce this padding on the server, ignoring any packets without it. Now our protocol effectively has DDoS _minification_ for requests -> responses, making it highly unattractive for anyone thinking of launching this kind of attack.

Finally, we'll do one last small thing to improve the robustness and security of the protocol. It's not perfect, we need authentication and encryption for that, but it at least it ups the ante, requiring attackers to actually sniff traffic in order to impersonate the client or server. We'll add some unique random identifiers, or 'salts', to make each client connection unique from previous ones coming from the same IP address and port.

The connection request packet now looks like this:

<img src="/img/network-protocol/connection-request-packet-2.0.png" width="100%"/>

The client salt in the packet is a random 64 bit integer rolled each time the client starts a new connect. Connection requests are now uniquely identified by the IP address and port combined with this client salt value. This distinguishes packets from the current connection from any packets belonging to a previous connection, which makes connection and reconnection to the server much more robust.

Now when a connection request arrives and a pending connection entry can't be found in the data structure (according to IP, port and client salt) the server rolls a server salt and stores it with the rest of the data for the pending connection before sending a challange packet back to the client. If a pending connection is found, the salt value stored in the data structure is used for the challenge. This way there is always a consistent pair of client and server salt values corresponding to each client session.

<img src="/img/network-protocol/challenge-packet.png" width="100%"/>

The client state machine has been expanded so **connecting** is replaced with two new states: **sending connection request** and **sending challenge response**, but it's the same idea as before. Client states repeatedly send the packet corresponding to that state to the server while listening for the response that moves it forward to the next state, or back to an error state. If no response is received, the client times out and transitions to **disconnected**.

The challenge response sent from the client to the server looks like this:

<img src="/img/network-protocol/challenge-response-packet.png" width="100%"/>

The utility of this being that once the client and server have established connection, we prefix all payload packets with the xor of the client and server salt values and discard any packets with the incorrect salt values. This neatly filters out packets from previous sessions and requires an attacker to sniff packets in order to impersonate a client or server.

<img src="/img/network-protocol/connection-payload-packet.png" width="100%"/>

Now that we have at least a _basic_ level of security, it's not much, but at least it's **something**, we can implement a disconnect packet:

<img src="/img/network-protocol/disconnect-packet.png" width="100%"/>

And when the client or server want to disconnect clean, they simply fire 10 of these over the network to the other side, in the hope that some of them get through, and the other side disconnects cleanly instead of waiting for timeout.

## Conclusion

We've discussed why first person shooters use UDP instead of TCP and created a simple client/server connection protocol on top of UDP based around the concept of client slots.

We explored the downsides of an inital naive implementation and hardened it against DDoS amplification and spoofed packet source addresses. We extended the protocol with client sessions using salt values, so packets from previous sessions are filtered out and attackers must sniff traffic to impersonate the client or server. We also added disconnect packets so clean disconnection doesn't have to wait for timeout.

But we're far from done. The protocol is greatly improved but it's still only one I would consider suitable for a LAN game played in your office. Hostile actors can still sniff traffic and impersonate a client or server, read the contents of your packets, modify them in transit, and spin up zombie clients to consume your dedicated server resources.

Stay tuned for the next article: **Securing Dedicated Servers** where I describe the best practices for securing your client/server UDP protocol, incorporating authentication, encryption and signing so only _real_ clients can connect to your dedicated server, your game traffic can't be read or modified in transit, and it's no longer possible to impersonate a client or server.
