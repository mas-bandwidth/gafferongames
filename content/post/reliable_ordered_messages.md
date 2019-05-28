+++
categories = ["Building a Game Network Protocol"]
tags = ["networking"]
date = "2016-09-15"
title = "Reliable Ordered Messages"
description = "How to implement reliable-ordered messages on top of UDP"
draft = false
+++

## Introduction

Hi, I’m [Glenn Fiedler](/about) and welcome to **[Building a Game Network Protocol](/categories/building-a-game-network-protocol/)**. 

Many people will tell you that implementing your own reliable message system on top of UDP is foolish. After all, why reimplement TCP? 

But why limit ourselves to how TCP works? But there are so many different ways to implement reliable-messages and most of them work _nothing_ like TCP! 

So let's get creative and work out how we can implement a reliable message system that's _better_ and _more flexible_ than TCP for real-time games.

## Different Approaches

A common approach to reliability in games is to have two packet types: reliable-ordered and unreliable. You'll see this approach in many network libraries. 

The basic idea is that the library resends reliable packets until they are received by the other side. This is the option that usually ends up looking a bit like TCP-lite for the reliable-packets. It's not that bad, but you can do much better.

The way I prefer to think of it is that messages are smaller bitpacked elements that know how to serialize themselves. This makes the most sense when the overhead of length prefixing and padding bitpacked messages up to the next byte is undesirable (eg. lots of small messages included in each packet). Sent messages are placed in a queue and each time a packet is sent some of the messages in the send queue are included in the outgoing packet. This way there are no reliable packets that need to be resent. Reliable messages are simply included in outgoing packets until they are received.

The easiest way to do this is to include all unacked messages in each packet sent. It goes something like this: each message sent has an id that increments each time a message is sent. Each outgoing packet includes the start _message id_ followed by the data for _n_ messages. The receiver continually sends back the most recent received message id to the sender as an ack and only messages newer than the most recent acked message id are included in packets.

This is simple and easy to implement but if a large burst of packet loss occurs while you are sending messages you get a spike in packet size due to unacked messages.

You can avoid this by extending the system to have an upper bound on the number of messages included per-packet _n_. But now if you have a high packet send rate (like 60 packets per-second) you are sending the same message multiple times until you get an ack for that message. 

If your round trip time is 100ms each message will be sent 6 times redundantly before being acked on average. Maybe you really need this amount of redundancy because your messages are extremely time critical, but in most cases, your bandwidth would be better spent on other things.

The approach I prefer combines packet level acks with a prioritization system that picks the n most important messages to include in each packet. This combines time critical delivery and the ability to send only n messages per-packet, while distributing sends across all messages in the send queue.

## Packet Level Acks

To implement packet level acks, we add the following packet header:

<pre>
struct Header
{
    uint16_t sequence;
    uint16_t ack;
    uint32_t ack_bits;
};
</pre>

These header elements combine to create the ack system: __sequence__ is a number that increases with each packet sent, __ack__ is the most recent packet sequence number received, and __ack_bits__ is a bitfield encoding the set of acked packets. 

If bit __n__ is set in __ack_bits__, then __ack - n__ is acked. Not only is __ack_bits__ a smart encoding that saves bandwidth, it also adds _redundancy_ to combat packet loss. Each ack is sent 32 times. If one packet is lost, there's 31 other packets with the same ack. Statistically speaking, acks are very likely to get through.

But bursts of packet loss do happen, so it's important to note that:

1. If you receive an ack for packet n then that packet was __definitely received__.

2. If you don't receive an ack, the packet was _most likely_ not received. But, it might have been, and the ack just didn't get through. __This is extremely rare__.

In my experience it's not necessary to send perfect acks. Building a reliability system on top of a system that very rarely drops acks adds no significant problems. But it does create a challenge for testing this system works under all situations because of the edge cases when acks are dropped.

So please if you do implement this system yourself, setup a soak test with terrible network conditions to make sure your ack system is working correctly. You'll find such a soak test in the [example source code](http://www.patreon.com/gafferongames) for this article, and the open source network libraries [reliable.io](https://github.com/networkprotocol/reliable.io) and [yojimbo](http://www.libyojimbo.com) which also implement this technique.

## Sequence Buffers

To implement this ack system we need a data structure on the sender side to track whether a packet has been acked so we can ignore redundant acks (each packet is acked multiple times via __ack_bits__. We also need a data structure on the receiver side to keep track of which packets have been received so we can fill in the __ack_bits__ value in the packet header.

The data structure should have the following properties:

* Constant time insertion (inserts may be _random_, for example out of order packets...)
* Constant time query if an entry exists given a packet sequence number
* Constant time access for the data stored for a given packet sequence number
* Constant time removal of entries

You might be thinking. Oh of course, _hash table_. But there's a much simpler way:

<pre>
const int BufferSize = 1024;

uint32_t sequence_buffer[BufferSize];

struct PacketData
{
    bool acked;
};

PacketData packet_data[BufferSize];

PacketData * GetPacketData( uint16_t sequence )
{
    const int index = sequence % BufferSize;
    if ( sequence_buffer[index] == sequence )
        return &amp;packet_data[index];
    else
        return NULL;
}
</pre>

As you can see the trick here is a rolling buffer indexed by sequence number:

<pre>
const int index = sequence % BufferSize;
</pre>

This works because we don't care about being destructive to old entries. As the sequence number increases older entries are naturally overwritten as we insert new ones. The sequence_buffer[index] value is used to test if the entry at that index actually corresponds to the sequence number you're looking for. A sequence buffer value of 0xFFFFFFFF indicates an empty entry and naturally returns NULL for any sequence number query without an extra branch.

When entries are added in order like a send queue, all that needs to be done on insert is to update the sequence buffer value to the new sequence number and overwrite the data at that index:

<pre>
PacketData &amp; InsertPacketData( uint16_t sequence )
{
    const int index = sequence % BufferSize;
    sequence_buffer[index] = sequence;
    return packet_data[index];
}
</pre>

Unfortunately, on the receive side packets arrive out of order and some are lost. Under ridiculously high packet loss (99%) I've seen old sequence buffer entries stick around from before the previous sequence number wrap at 65535 and break my ack logic (leading to false acks and broken reliability where the sender thinks the other side has received something they haven't...). 

The solution to this problem is to walk between the previous highest insert sequence and the new insert sequence (if it is more recent) and clear those entries in the sequence buffer to 0xFFFFFFFF. Now in the common case, insert is _very close_ to constant time, but worst case is linear where n is the number of sequence entries between the previous highest insert sequence and the current insert sequence.

Before we move on I would like to note that you can do much more with this data structure than just acks. For example, you could extend the per-packet data to include time sent:

<pre>struct PacketData
{
    bool acked;
    double send_time;
};
</pre>

With this information you can create your own estimate of round trip time by comparing send time to current time when packets are acked and taking an [exponentially smoothed moving average](https://en.wikipedia.org/wiki/Exponential_smoothing). You can even look at packets in the sent packet sequence buffer older than your RTT estimate (you should have received an ack for them by now...) to create your own packet loss estimate.

## Ack Algorithm

Now that we have the data structures and packet header, here is the algorithm for implementing packet level acks:

__On packet send:__

1. Insert an entry for for the current send packet sequence number in the sent packet sequence buffer with data indicating that it hasn't been acked yet

2. Generate __ack__ and __ack_bits__ from the contents of the local received packet sequence buffer and the most recent received packet sequence number

3. Fill the packet header with __sequence__, __ack__ and __ack_bits__

4. Send the packet and increment the send packet sequence number

__On packet receive:__

1. Read in __sequence__ from the packet header

2. If __sequence__ is more recent than the previous most recent received packet sequence number, update the most recent received packet sequence number

3. Insert an entry for this packet in the received packet sequence buffer

4. Decode the set of acked packet sequence numbers from __ack__ and __ack_bits__ in the packet header.

5. Iterate across all acked packet sequence numbers and for any packet that is not already acked call __OnPacketAcked__( uint16_t sequence ) and mark that packet as _acked_ in the sent packet sequence buffer.

Importantly this algorithm is done on both sides so if you have a client and a server then each side of the connection runs the same logic, maintaining its own sequence number for sent packets, tracking most recent received packet sequence # from the other side and a sequence buffer of received packets from which it generates __sequence__, __ack__ and __ack_bits__ to send to the other side.

And that's really all there is to it. Now you have a callback when a packet is received by the other side: __OnPacketAcked__. The main benefit of this ack system is now that you know which packets were received, you can build _any_ reliability system you want on top. It's not limited to just reliable-ordered messages. For example, you could use it to implement delta encoding on a per-object basis.

## Message Objects

Messages are small objects (smaller than packet size, so that many will fit in a typical packet) that know how to serialize themselves. In my system they perform serialization using a [unified serialize function](http://gafferongames.com/building-a-game-network-protocol/serialization-strategies)unified serialize function.

The serialize function is templated so you write it once and it handles read, write and _measure_.

Yes. Measure. One of my favorite tricks is to have a dummy stream class called __MeasureStream__ that doesn't do any actual serialization but just measures the number of bits that _would_ be written if you called the serialize function. This is particularly useful for working out which messages are going to fit into your packet, especially when messages themselves can have arbitrarily complex serialize functions.

<pre>
struct TestMessage : public Message
{
    uint32_t a,b,c;

    TestMessage()
    {
        a = 0;
        b = 0;
        c = 0;
    }

    template &lt;typename Stream&gt; bool Serialize( Stream &amp; stream )
    { 
        serialize_bits( stream, a, 32 );
        serialize_bits( stream, b, 32 );
        serialize_bits( stream, c, 32 );
        return true;
    }

    virtual SerializeInternal( WriteStream &amp; stream )
    {
        return Serialize( stream );
    }

    virtual SerializeInternal( ReadStream &amp; stream )
    {
        return Serialize( stream );
    }

    virtual SerializeInternal( MeasureStream &amp; stream )
    {
        return Serialize( stream );        
    }
};
</pre>

The trick here is to bridge the unified templated serialize function (so you only have to write it once) to virtual serialize methods by calling into it from virtual functions per-stream type. I usually wrap this boilerplate with a macro, but it's expanded in the code above so you can see what's going on.

Now when you have a base message pointer you can do this and it _just works_:

<pre>
Message * message = CreateSomeMessage();
message-&gt;SerializeInternal( stream );
</pre>

An alternative if you know the full set of messages at compile time is to implement a big switch statement on message type casting to the correct message type before calling into the serialize function for each type. I've done this in the past on console platform implementations of this message system (eg. PS3 SPUs) but for applications today (2016) the overhead of virtual functions is neglible.

Messages derive from a base class that provides a common interface such as serialization, querying the type of a message and reference counting. Reference counting is necessary because messages are passed around by pointer and stored not only in the message send queue until acked, but also in outgoing packets which are themselves C++ structs.

This is a strategy to avoid copying data by passing both messages and packets around by pointer. Somewhere else (ideally on a separate thread) packets and the messages inside them are serialized to a buffer. Eventually, when no references to a message exist in the message send queue (the message is acked) and no packets including that message remain in the packet send queue, the message is destroyed.

We also need a way to create messages. I do this with a message factory class with a virtual function overriden to create a message by type. It's good if the packet factory also knows the total number of message types, so we can serialize a message type over the network with tight bounds and discard malicious packets with message type values outside of the valid range:

<pre>
enum TestMessageTypes
{
    TEST_MESSAGE_A,
    TEST_MESSAGE_B,
    TEST_MESSAGE_C,
    TEST_MESSAGE_NUM_TYPES
};

// message definitions omitted

class TestMessageFactory : public MessageFactory
{ 
public:

    Message * Create( int type )
    {
        switch ( type )
        {
            case TEST_MESSAGE_A: return new TestMessageA();
            case TEST_MESSAGE_B: return new TestMessageB();
            case TEST_MESSAGE_C: return new TestMessageC();
        }
    }

    virtual int GetNumTypes() const
    {
        return TEST_MESSAGE_NUM_TYPES;
    }
};
</pre>

Again, this is boilerplate and is usually wrapped by macros, but underneath this is what's going on.

## Reliable Ordered Message Algorithm

The algorithm for sending reliable-ordered messages is as follows:

__On message send:__

1. Measure how many bits the message serializes to using the measure stream

2. Insert the message pointer and the # of bits it serializes to into a sequence buffer indexed by message id. Set the time that message has last been sent to -1

3. Increment the send message id

__On packet send:__

1. Walk across the set of messages in the send message sequence buffer between the oldest unacked message id and the most recent inserted message id from left -&gt; right (increasing message id order).

2. Never send a message id that the receiver can't buffer or you'll break message acks (since that message won't be buffered, but the packet containing it will be acked, the sender thinks the message has been received, and will not resend it). This means you must _never_ send a message id equal to or more recent than the oldest unacked message id plus the size of the message receive buffer.

3. For any message that hasn't been sent in the last 0.1 seconds _and_ fits in the available space we have left in the packet, add it to the list of messages to send. Messages on the left (older messages) naturally have priority due to the iteration order.

4. Include the messages in the outgoing packet and add a reference to each message. Make sure the packet destructor decrements the ref count for each message.

5. Store the number of messages in the packet __n__ and the array of message ids included in the packet in a sequence buffer indexed by the outgoing packet sequence number so they can be used to map packet level acks to the set of messages included in that packet.

6. Add the packet to the packet send queue.

__On packet receive:__

1. Walk across the set of messages included in the packet and insert them in the receive message sequence buffer indexed by their message id.

2. The ack system automatically acks the packet sequence number we just received.

__On packet ack:__

1. Look up the set of messages ids included in the packet by sequence number.

2. Remove those messages from the message send queue if they exist and decrease their ref count.

3. Update the last unacked message id by walking forward from the previous unacked message id in the send message sequence buffer until a valid message entry is found, or you reach the current send message id. Whichever comes first.

__On message receive:__

1. Check the receive message sequence buffer to see if a message exists for the current receive message id.

2. If the message exists, remove it from the receive message sequence buffer, increment the receive message id and return a pointer to the message.

3. Otherwise, no message is available to receive. Return __NULL__.

In short, messages keep getting included in packets until a packet containing that message is acked. We use a data structure on the sender side to map packet sequence numbers to the set of message ids to ack. Messages are removed from the send queue when they are acked. On the receive side, messages arriving out of order are stored in a sequence buffer indexed by message id, which lets us receive them in the order they were sent.

## The End Result

This provides the user with an interface that looks something like this on send:

<pre>
TestMessage * message = (TestMessage*) factory.Create( TEST_MESSAGE );
if ( message )
{
    message-&gt;a = 1;
    message-&gt;b = 2;
    message-&gt;c = 3;
    connection.SendMessage( message );
}</pre>

And on the receive side:

<pre>
while ( true )
{
    Message * message = connection.ReceiveMessage();
    if ( !message )
        break;

    if ( message-&gt;GetType() == TEST_MESSAGE )
    {
        TestMessage * testMessage = (TestMessage*) message;
        // process test message
    }

    factory.Release( message );
}
</pre>

Which is flexible enough to implement whatever you like on top of it.

__NEXT ARTICLE__: [Client Server Connection](/post/client_server_connection/)
