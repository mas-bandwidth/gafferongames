+++
categories = ["Building a Game Network Protocol"]
tags = ["networking"]
date = "2016-09-15"
title = "Reliable Ordered Messages"
description = "How to implement reliable-ordered messages on top of UDP"
draft = true
+++

## Introduction

Hi, I'm Glenn Fiedler and welcome to the fifth article in <a href="http://gafferongames.com/building-a-game-network-protocol/">Building a Game Network Protocol</a>.

It's been quite a while since the <a href="http://gafferongames.com/building-a-game-network-protocol/sending-large-blocks-of-data/">last article</a> and in that time I've run ahead and implemented code for the rest this series and created the open source library <a href="https://github.com/networkprotocol/libyojimbo">libyojimbo</a>, a hardened and unit-tested library version of the network protocol described in this article series.

If you want an open-source library to implement reliable messages over UDP for you and much more, check out <a href="https://github.com/networkprotocol/libyojimbo">libyojimbo</a>. But, if you're like me and you want to understand exactly how it all works and maybe implement it yourself, read on because we're going to build up a complete system for sending reliable-ordered messages over UDP from scratch!

## Introduction

Many people will tell you that implementing your own reliable message system on top of UDP is foolish. Why write your own poor version of TCP? These people are convinced that any implementation of reliability <em><span style="text-decoration: underline;">inevitably</span></em> ends up being a (poor) reimplementation of TCP.

But there are many different ways to implement reliable-messages over UDP, each with different strengths and weaknesses. TCP-lite isn't the only option. In fact, most options for reliable-ordered messages I can think of work nothing like TCP. So lets get creative and work out how we can take advantage of our situation to implement a reliability system that's <em><span style="text-decoration: underline;">better</span></em> than TCP for our purpose.

The defining feature for network protocols in the action game genre (FPS) is a <span style="text-decoration: underline;">carrier wave</span> of packets sent in both directions at a steady rate like 20 or 30 packets per-second. These packets contain unreliable-unordered data such as the state of the world at time t; so when a packet is lost, resending it isn't particularly useful. By the time the resent packet arrives, time t has already passed.

So this is the situation in which we are implementing reliability. For 90% of our packet data it's best to just drop it and never resend it. For 10% or less (give or take) we actually do need reliability but this data is rare, infrequently sent and smaller than the unreliable data on average. This use case matches all AAA FPS games released in the last 15 years.

## Different Approaches

One common approach to reliability is to have two packet types: reliable-ordered and unreliable. You'll see this approach in many network libraries. The basic idea is that the library resends reliable packets until they are received by the other side. This is the option that usually ends up looking a bit like TCP-lite for the reliable-packets. It's not that bad, but you can do much better.

The way I prefer to think of it is that messages are smaller bitpacked elements that know how to serialize themselves. This makes the most sense when the overhead of length prefixing and padding bitpacked messages up to the next byte is undesirable (eg. lots of small messages included in each packet). Sent messages are placed in a queue and each time a packet is sent some of the messages in the send queue are included in the outgoing packet. This way there are no reliable packets that need to be resent. Reliable messages are just included in packets until they are received.

The easiest way to do this is to include all unacked messages in each packet sent. It goes something like this: each message sent has an id that increments each time a message is sent. Each outgoing packet includes the start <strong>message id</strong> followed by the data for <strong>n</strong> messages. The receiver continually sends back the most recent received message id to the sender as an ack and only messages newer than the most recent acked message id are included in packets.

This is simple and easy to implement but if a large burst of packet loss occurs while you are sending messages you get a spike in packet size due to unacked messages. As discussed in <a href="http://gafferongames.com/building-a-game-network-protocol/packet-fragmentation-and-reassembly/">packet fragmentation and reassembly</a> sending large packets that require MTU fragmentation results in packet loss amplification. The last thing you want to do while under high packet loss is to increase packet size and induce even more packet loss. It's a potential death spiral.

You can avoid this by extending the system to have an upper bound on the number of messages included per-packet <strong>n</strong>. But now if you have a high packet send rate (like 60 packets per-second) you are sending the same message multiple times until you get an ack for that message. If your round trip time is 100ms each message will be sent 6 times redundantly before being acked on average. Maybe you really need this amount of redundancy because your messages are extremely time critical, but in most cases, your bandwidth would be better spent distributed across other messages in the send queue.

The approach I prefer combines per-packet acks with a prioritization system that picks the n most important messages to include in each packet. This combines time critical delivery and the ability to send only n messages per-packet, while distributing message sends across all messages in the send queue.

## Packet Level Acks

Lets move on to implementation.

The foundation of this reliability system is per-packet acks.

But why do acks at the packet level instead of the message level? In short the reason is that there are fewer packets than messages. Assuming 32 or 64 messages per-packet, it's clearly more efficient to ack a single packet containing 32 or 64 messages than to ack each message individually.

It also adds flexibility because you can build other reliability systems on top of packet level acks, not just reliable-ordered messages. For example, with packet level acks you know which time critical unreliable state updates got through, so you can easily build a system that stops sending state for unchanging objects once a packet containing their last state update is acked.

To implement packet level acks, add the following header in front of each packet:

<pre>
struct Header
{
    uint16_t sequence;
    uint16_t ack;
    uint32_t ack_bits;
};
</pre>

These header elements combine to create the ack system:

<ul>
    <li><strong>sequence</strong> is a number that increases with each packet sent (and wraps around after 65535).</li>
    <li><strong>ack</strong> is the most recent packet sequence number received from the other side.</li>
    <li><strong>ack_bits</strong> is a bitfield encoding the set of packets received relative to <strong>ack: </strong>if bit <strong>n </strong>is set then packet <strong>ack</strong> <strong>-</strong> <strong>n</strong> was received.</li>
</ul>

Not only is <strong>ack_bits</strong> a smart encoding of acks that saves bandwidth, it also adds <span style="text-decoration: underline;">redundancy</span> to combat packet loss. Each ack is sent 32 times. If one packet is lost, there's 31 other packets with the same ack. Statistically speaking, acks are very likely to get through.

But bursts of packet loss do happen, so it's important to note that:

<ol>
    <li>If you receive an ack for packet n then that packet was <span style="text-decoration: underline;">definitely received</span><em>.</em></li>
    <li>If you don't receive an ack, the packet was <em>most likely</em> not received. But... it might have been, and the ack just didn't get through. <span style="text-decoration: underline;">This is extremely rare</span>.</li>
</ol>

In my experience it's not necessary to send perfect acks. Building a reliability system on top of a system that very rarely drops acks adds no significant problems. But it does create a challenge for testing this system works under all situations because of the edge cases when acks are dropped.

So please if you do implement this system yourself, setup a soak test with terrible network conditions to make sure your ack system is working correctly, and by extension, that your message system implementation actually delivers reliable-ordered messages <em><span style="text-decoration: underline;">reliably and in-order</span> </em>under these network conditions. In my experience (and I've written variants of this system at least 10 times...) this is a necessary step to ensure correct behavior.

You'll find such a soak test in the example source code for this article which is available for <a href="https://www.patreon.com/gafferongames">patreon supporters</a>, and in the open source network libary <a href="http://www.libyojimbo.com">libyojimbo</a>.

## Sequence Buffers

To implement this ack system we need a data structure on the sender side to track whether a packet has been acked so we can ignore redundant acks (each packet is acked multiple times via <strong>ack_bits</strong>). We also need a data structure on the receiver side to keep track of which packets have been received so we can fill in the <strong>ack_bits</strong> value in the packet header.

The data structure should have the following properties:

<ul>
    <li>Constant time insertion (inserts may be <em><span style="text-decoration: underline;">random</span></em>, for example out of order packets...)</li>
    <li>Constant time query if an entry exists given a packet sequence number</li>
    <li>Constant time access for the data stored for a given packet sequence number</li>
    <li>Constant time removal of entries</li>
</ul>

You might be thinking. Oh of course, <em><span style="text-decoration: underline;">hash table</span></em>. But there's a much simpler way:

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
But on the receive side packets arrive out of order and some are lost. Under ridiculously high packet loss (99%) I've seen old sequence buffer entries stick around from before the previous sequence number wrap at 65535 and break my ack logic (leading to false acks and broken reliability where the sender thinks the other side has received something they haven't...)

The solution to this problem is to walk between the previous highest insert sequence and the new insert sequence (if it is more recent) and clear those entries in the sequence buffer to 0xFFFFFFFF. Now in the common case, insert is <em><span style="text-decoration: underline;">very close</span></em> to constant time, but worst case is linear where n is the number of sequence entries between the previous highest insert sequence and the current insert sequence.

Before we move on I would like to note that you can do much more with this data structure than just acks. For example, you could extend the per-packet data to include time sent:

<pre>struct PacketData
{
    bool acked;
    double send_time;
};
</pre>

With this information you can create your own estimate of round trip time by comparing send time to current time when packets are acked and taking an <a href="https://en.wikipedia.org/wiki/Exponential_smoothing">exponentially smoothed moving average</a>. You can even look at packets in the sent packet sequence buffer older than your RTT estimate (you should have received an ack for them by now...) to create your own packet loss estimate.

## Ack Algorithm

Now lets focus on the actual algorithm for packet level acks.

The algorithm is as follows:

<strong>On packet send:</strong>
<ol>
    <li>Insert an entry for for the current send packet sequence number in the sent packet sequence buffer with data indicating that it hasn't been acked yet</li>
    <li>Generate <strong>ack</strong> and <strong>ack_bits</strong> from the contents of the local received packet sequence buffer and the most recent received packet sequence number</li>
    <li>Fill the packet header with <strong>sequence, ack</strong> and <strong>ack_bits</strong></li>
    <li>Send the packet and increment the send packet sequence number</li>
</ol>

<strong>On packet receive:</strong>
<ol>
    <li>Read in <strong>sequence</strong> from the packet header</li>
    <li>If <strong>sequence</strong> is more recent than the previous most recent received packet sequence number, update the most recent received packet sequence number</li>
    <li>Insert an entry for this packet in the received packet sequence buffer</li>
    <li>Decode the set of acked packet sequence numbers from <strong>ack</strong> and <strong>ack_bits</strong> in the packet header.</li>
    <li>Iterate across all acked packet sequence numbers and for any packet that is not already acked call <strong>OnPacketAcked</strong>( uint16_t sequence ) and set that packet as 'acked' in the sent packet sequence buffer</li>
</ol>

Importantly this algorithm is done on both sides so if you have a client and a server then each side of the connection runs the same logic, maintaining its own sequence number for sent packets, tracking most recent received packet sequence # from the other side and a sequence buffer of received packets from which it generates <strong>sequence, </strong><strong>ack</strong> and <strong>ack_bits</strong> to send to the other side.

And that's really all there is to it. Now you have a callback when a packet is received by the other side: <strong>OnPacketAcked</strong>. The key to this reliability system is now that you know which packets were  received, you can build <em><span style="text-decoration: underline;">any</span></em> reliability system you want on top. It's not limited to just reliable-ordered messages.  For example, you could use it for to know which unreliable state updates actually got through to implement delta encoding on a per-object basis.

## Message Objects

Messages are small objects (smaller than packet size, so that many will fit in a typical packet) that know how to serialize themselves. In my system they perform serialization using a <a href="http://gafferongames.com/building-a-game-network-protocol/serialization-strategies/">unified serialize function</a>.

The serialize function is templated so you write it once and it handles read, write and <em><span style="text-decoration: underline;">measure</span>. </em>

Yes. Measure. One of my favorite tricks is to have a dummy stream class called <strong>MeasureStream</strong> that doesn't do any actual serialization but just measures the number of bits that <em><span style="text-decoration: underline;">would</span></em> be written if you called the serialize function. This is particularly useful for working out which messages are going to fit into your packet, especially when messages can have arbitrarily complex serialize functions.

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

Now when you have a base message pointer you can do this and it just works via overloading:

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

Now lets get down to the details of how to implement reliable-ordered messages on top of the ack system.

The algorithm for sending reliable-ordered messages is as follows:

<strong>On message send:</strong>
<ol>
    <li>Measure how many bits the message serializes to using the measure stream</li>
    <li>Insert the message pointer and the # of bits it serializes to into a sequence buffer indexed by message id. Set the time that message has last been sent to -1</li>
    <li>Increment the send message id</li>
</ol>

<strong>On packet send:</strong>
<ol>
    <li>Walk across the set of messages in the send message sequence buffer between the oldest unacked message id and the most recent inserted message id from left -&gt; right (increasing message id order).</li>
    <li><strong>SUPER IMPORTANT:</strong> Never send a message id that the receiver can't buffer or you'll break message acks (since that message won't be buffered, but the packet containing it will be acked, the sender thinks the message has been received, and will not resend it). This means you must <em><span style="text-decoration: underline;">never</span></em> send a message id equal to or more recent than the oldest unacked message id plus the size of the message receive buffer.</li>
    <li>For any message that hasn't been sent in the last 0.1 seconds <span style="text-decoration: underline;">and</span> fits in the available space we have left in the packet, add it to the list of messages to send. Messages on the left (older messages) naturally have priority due to the iteration order.</li>
    <li>Include the messages in the outgoing packet and add a reference to each message. Make sure the packet destructor decrements the ref count for each message.</li>
    <li>Store the number of messages in the packet <strong>n</strong> and the array of message ids included in the packet in a sequence buffer indexed by the outgoing packet sequence number.</li>
    <li>Add the packet to the packet send queue.</li>
</ol>

<strong>On packet receive:</strong>
<ol>
    <li>Walk across the set of messages included in the packet and insert them in the receive message sequence buffer indexed by their message id.</li>
    <li>The ack system automatically acks the packet sequence number we just received.</li>
</ol>

<strong>On packet ack:</strong>
<ol>
    <li>Look up the set of messages ids included in the packet by sequence number.</li>
    <li>Remove those messages from the message send queue if they exist and decrease their ref count.</li>
    <li>Update the last unacked message id by walking forward from the previous unacked message id in the send message sequence buffer until a valid message entry is found, or you reach the current send message id. Whichever comes first.</li>
</ol>

<strong>On message receive:</strong>
<ol>
    <li>Check the receive message sequence buffer to see if a message exists for the current receive message id.</li>
    <li>If the message exists, remove it from the receive message sequence buffer, increment the receive message id and return a pointer to the message.</li>
    <li>Otherwise, no message is available to receive. Return <strong>NULL</strong>.</li>
</ol>

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

I hope you're enjoyed the writing in this series so far. <a href="http://www.patreon.com/gafferongames">Please support my writing on patreon</a>, and I'll write new articles faster, plus you get access to example source code for this article under the BSD open source licence. <strong><span style="text-decoration: underline;">Thanks for your support</span>!</strong>

<hr>

_If you enjoyed this article, please [support my work](http://www.patreon.com) on Patreon and encourage me to write more articles. Patreon supporters also get access to exclusive supporter content, like example source code for articles and previews of work in progress!_

__NEXT ARTICLE:__ ...
