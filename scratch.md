










<hr>
<hr>
<hr>
<hr>

_(very rough draft below here)_


To handle this, instead of implementing some sort of reliability at this early stage, we'll create the concept of connection as a set of parallel state machines on the client and server that are able to handle packet loss.










## How Many Clients Per-Server?

How many client slots should you open? That depends entirely on the game. I recommend the approach in this article for games with [2,64] clients per-server. Any more than 64 and you start creeping in to MMO territory where the best practice may differ from what is presented here. You'll notice that most first person shooters in 2016 are in this range. For example, [Battlefield 1](https://en.wikipedia.org/wiki/Battlefield_1) has a maximum of 64 players.

This is a far cry from web development where [C10K is old hat](https://linuxjedi.co.uk/posts/2015/Feb/14/why-the-c10k-problem-is-important/). What's going on? Why are game servers able to handle only a tiny fraction of the number of connected clients of a web server from the late 90s? :)

The key thing to remember is that a game server represents a shared instance of the game world where players can directly interact with each other. Shooting enemies, helping teammates, fighting against the same AIs and inhabiting the same world. Any change made by one player must be reflected to the rest of the players in that instance. 

Each client slot corresponds to a player in that game instance. This isn't a stateless system. This isn't request/response. The game server runs a simulation of the entire game world that steps forward 60 times per-second. The server _is_ the game. Because of this, game servers tend to be simulation, not I/O bound. Effort spent optimizing game servers is all about how cheaply the game simulation can be made to run, so more game server instances, and therefore more players, can be handled by the same amount of hardware. 

In most cases each client slot corresponds to a connected player in the game. For this reason it's good for clients to know which client slot they are assigned to, so they know if they are player 1, player 2 or player n. By convention, player numbers are usually considered to be client index + 1. 

This way the client index lets players identify themselves and other players in the game, both when sending and receiving packets and in game code. For example, the server might send a packet to client 4, and receive a packet from client 10, while in a first person shooter you are killed by player 5 and the camera zooms in on that player and maybe shows a kill replay from their point of view. This is how we want everything to appear in our abstraction, not IP addresses, but client indices in [0,MaxClients-1].

Why is it so important to use client indices? The answer is security. The last thing we want in a competitive game is to expose player's IP addresses to each other, because some people try to DDoS people off the Internet. High profile streamers deal with this all the time. For these reasons, and many others, virtual client slots make a lot of sense.

## Implementation

_(todo: draft below here...)_

Let's get down to implementation.

First, the client and server both have their own UDP socket. Let's say the client binds to an ephemiral port, and the server binds to port 50000. 

Unlike a TCP-server where each accepted connection gets its own socket, the UDP server processes packets for all clients on the same socket. Also, since UDP is unreliabile, we need a strategy for packets being lost. We do this not by implementing a complicated reliability system at this early stage, but by implementing parallel state machines on the client and on the server:

At this early stage we have this state machine on the client:

* Disconnected
* Connecting
* Connected

And on the server, let's start with a bool "connected" for each slot, and the client address that is assigned to that slot:

    const int MaxClients = 64;

    class Server
    {
        int m_numConnectedClients;
        bool m_clientConnected[MaxClients];
        Address m_clientAddress[MaxClients];
    };

While the client is in the connection request state, it sends "connection request" packets to the server 10 times per-second. This continues until the client receives a response from the server, or the connection request times out. This simple approach works well and leaves the complexity of implementing reliability over UDP until _after_ a connection has been established.

For example “connection accepted” response packet could be lost. This is handled by making the server respond to each request (or at least, setting a dirty flag to trigger a response) each time a request is received. That way if the first “connect accepted” packet doesn’t get through, the next “connection request” from the client triggers another response. This way, by some sort of strange induction, the client and server are able to advance forward through an arbitrarily complicated state machine until they are both connected.

On the server there have a similar state machine, but this time it is per-client. For the moment, lets keep it simple with a basic data structure which simply keeps track of whether a client slot is assigned to a particular client IP+port:

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

    const Address & Server::GetClientAddress( int clientIndex ) const
    {
        assert( clientIndex >= 0 );
        assert( clientIndex < m_maxClients );
        return m_clientAddress[clientIndex];
    }

and retrieve a client’s IP address and port by client index:

    const Address & Server::GetClientAddress( int clientIndex ) const
    {
        assert( clientIndex >= 0 );
        assert( clientIndex < m_maxClients );
        return m_clientAddress[clientIndex];
    }

For example "connection accepted" response packet could be lost. This is handled by making the server respond to each request (or at least, setting a dirty flag to trigger a response) each time a request is received. That way if the first "connect accepted" packet doesn't get through, the next "connection request" from the client triggers another response. This way, by some sort of strange induction, the client and server are able to advance forward through an arbitrarily complicated state machine until they are both connected.

On the server, we add the following data structure:






With these simple queries, the server is ready to start processing connection requests from clients.
