+++
categories = ["Building a Game Network Protocol"]
tags = ["networking"]
date = "2016-09-01"
title = "Reading and Writing Packets"
description = "Best practices when reading and writing packets"
draft = true
+++

## Introduction


Hi, I’m <a href="https://www.linkedin.com/in/glennfiedler">Glenn Fiedler</a> and welcome to **Building a Game Network Protocol**. 

In this article series I’m going to build up a professional-grade client/server network protocol for action games like first person shooters.

-- todo: fill out intro. it's too sparse.

## Background

If you come from a web development background you’ve probably used XML, JSON or YAML to send data over the network in text format. This works reasonably well in the web development, but text is rarely used for game network protocols. Why?

Consider a web server. It listens for requests, does some work asynchronously and sends responses back to clients. It’s stateless and generally not real-time, although a fast response time is great.

In contrast, a game server is a real-time simulation of a game world. It's job is to advance the state of the game world forward with inputs from each client, before broadcasting out the latest state to all connected clients. These are totally different situations!

The network traffic patterns are different too. Instead of infrequent request/response from tens of thousands of clients, a game server has far fewer clients, but processes a continuous stream of input packets sent from each client 60 times per-second, and broadcasts out the state of the world to clients 10, 20 or even 60 times per-second.

And this state is __huge__. Thousands of objects with hundreds of properties each. Game network programmers spend a lot of time optimizing exactly how this state is sent over the network with crazy bit-packing tricks, hand-coded binary formats and delta encoding.

What would happen if we just encoded this world state as XML?

<pre>&lt;world_update world_time="0.0"&gt;
  &lt;object id="1" class="player"&gt;
    &lt;property name="position" value="(0,0,0)"&lt;/property&gt;
    &lt;property name="orientation" value="(1,0,0,0)"&lt;/property&gt;
    &lt;property name="velocity" value="(10,0,0)"&lt;/property&gt;
    &lt;property name="health" value="100"&gt;&lt;/property&gt;
    &lt;property name="weapon" value="110"&gt;&lt;/property&gt;
    ... 100s more properties per-object ...
   &lt;/object&gt;
 &lt;object id="100" class="grunt"&gt;
   &lt;property name="position" value="(100,100,0)"&lt;/property&gt;
   &lt;property name="health" value="10"&lt;/property&gt;
 &lt;/object&gt;
 &lt;object id="110" class="weapon"&gt;
   &lt;property type="semi-automatic"&gt;&lt;/property&gt;
   &lt;property ammo_in_clip="8"&gt;&lt;/property&gt;
   &lt;property round_in_chamber="true"&gt;&lt;/property&gt;
 &lt;/object&gt;
 ... 1000s more objects ...
&lt;/world_update&gt;
</pre>

Not so great...

JSON is a bit more compact:

<pre>
{
  "world_time": 0.0,
  "objects": {
    1: {
      "class": "player",
      "position": "(0,0,0)",
      "orientation": "(1,0,0,0)",
      "velocity": "(10,0,0)",
      "health": 100,
      "weapon": 110
    }
    100: {
      "class": "grunt",
      "position": "(100,100,0)",
      "health": 10
    }
    110: {
      "class": "weapon",
      "type: "semi-automatic"
      "ammo_in_clip": 8,
      "round_in_chamber": 1 
    }
  }
}
</pre>

But it still suffers from the same problem. The description of the data is larger than the data itself. What if instead of fully describing the world state in each packet, we split it up into two parts?

 1. A schema that describes the set of object classes and properties per-class, **sent only once** when a client connects to the server.
  
 2. Data sent rapidly from server to client, **which is encoded relative to the schema**.

The schema could look something like this:

<pre>{
  "classes": {
    0: "player" {
      "properties": {
        0: {
          "name": "position",
          "type": "vec3f"
        }
        1: {
          "name": "orientation",
          "type": "quat4f"
        }
        2: {
          "name": "velocity",
          "type": "vec3f"
        }
        3: {
          "name": "health",
          "type": "float"
        }
        4: {
          "name": "weapon",
          "type": "object", 
        }
      }
    }
    1: "grunt": {
      "properties": {
        0: {
          "name": "position",
          "type": "vec3f"
        }
        1: {
          "name": "health",
          "type": "float"
        }
      }
    }
    2: "weapon": {
      "properties": {
        0: {
          "name": "type",
          "type": "enum",
          "enum_values": [ "revolver", "semi-automatic" ]
        }
        1: {
          "name": "ammo_in_clip",
          "type": "integer",
          "range": "0..9",
        }
        2: {
          "name": "round_in_chamber",
          "type": "integer",
          "range": "0..1"
        }
      }
    }  
  }
}</pre>

The schema is quite big, but that's beside the point. It's sent only once, and now the client knows the set of classes in the game world and the number, name, type and range of properties for each class. 

With this knowledge we can make the rapidly sent portion of the world state much more compact:

<pre>
{
  "world_time": 0.0,
  "objects": {
    1: [0,"(0,0,0)","(1,0,0,0)","(10,0,0)",100,110],
    100: [1,"(100,100,0)",10],
    110: [2,1,8,1]
  }
}
</pre>

And we can compress even further by switching to a custom text format:

<pre>
0.0
1:0,0,0,0,1,0,0,0,10,0,0,100,110
100:1,100,100,0,10
110:2,1,8,1
</pre>

As you can see, with game network programming it’s much more about what you __don’t send__ than what you do.

## The Inefficiencies of Text

We’ve made good progress on our text format so far, moving from a highly attributed stream that fully describes the data (more description than actual data) to an unattributed text format that's an order of magnitude more efficient.

But there are inherent inefficiencies when using text formats for packet data:

 * We are most often sending data in the range __A-Z__, __a-z__ and __0-1__, plus a few other symbols. This wastes the remainder of the __0-255__ range for each character sent. From an information theory standpoint, this is an inefficient encoding.

 * The text representation of integer values are in the general case much less efficient than the binary format. For example, in text format the worst case unsigned 32 bit integer __4294967295__ takes 10 bytes, but in binary format it takes just four.

 * In text, even the smallest numbers in __0-9__ range require at least one byte, but in binary, smaller values like __0, 11, 31, 100__ can be sent with fewer than 8 bits if we know their range ahead of time.

 * If an integer value is negative, you have to spend a whole byte on __'-'__ to indicate that.

 * Floating point numbers waste one byte specifying the decimal point __'.'__

 * The text representation of numerical values are variable length: <strong>“5”</strong>, <strong>“12345”</strong>, <strong>“3.141593”. </strong>Because of this we need to spend one byte on a separator after each value so we know when it ends. No separators are required in binary because the number of bits required can be determined as a function of the range of its possible values, which are known by both sides.

 * Newlines __'\n'__ or some other separator are required to distinguish between the set of variables belonging to one object and the next. When you have thousands of objects, this really adds up.

In short, if we wish to optimize any further, it's necessary to switch to a binary format.

## Switching to a Binary Format

In the web world there are some really great libraries that read and write binary formats like <a href="http://bjson.org">BJSON</a>, <a href="https://developers.google.com/protocol-buffers/">Protocol Buffers</a>, <a href="https://google.github.io/flatbuffers/">Flatbuffers</a>, <a href="https://thrift.apache.org">Thrift</a>, <a href="https://capnproto.org">Cap’n Proto</a> and <a href="http://msgpack.org/index.html">MsgPack</a>. In some cases, these libraries can be a great fit for building your game network protocol.

But in the fast-paced world of first person shooters where efficiency is paramount, a hand-tuned binary protocol is the standard solution.

-- todo: fill out this logic. it's stilted.

There are a few reasons for this. Web binary formats are designed for a situation where versioning of data is <em><span style="text-decoration: underline;">extremely</span> </em>important (if you upgrade your backend, older clients should be able to keep talking to it with the old format). Language agnostic data formats are also key; a backend written in golang should be able to talk with a web client running inside a browser in JavaScript and microservices written in different languages should be able to communicate without having to upgrade all components at the same time.

Game servers for AAA FPS games are completely different beasts. The client and server are almost always written in the same language (C++) because large portions of the game code must run identically on the server and the client for client-side prediction. Versioning is much simpler as well, because if a client with an incompatible game version tries to connect to a game server, that connection is simply rejected. This may seem like a problem, but in practice, game clients are typically required to update to new client versions before they can play online anyway and in development your matchmaker can ensure that clients are sent to game server instances with compatible game versions.

So if you don’t need versioning and you don’t need cross-language support what are the benefits for these libraries? Convenience. Ease of use. Not needing to worry about creating, testing and debugging your own binary format. But this convenience is offset by the fact that these libraries are less efficient than a binary protocol we can roll ourselves. We know more about the data we are sending than any library writer ever could and we can take advantage of this to send less bits by developing our own custom binary format.

## Getting Started with a Binary Format

One option for creating your own binary protocol is to use the in-memory format of your data structures in C/C++ as the over-the-wire format. People often start here, so although I don’t recommend this approach, lets explore it for a while before we poke holes in it.

First define the set of packets, typically as a union of structs:

<pre>
struct Packet
{
    enum PacketTypeEnum { PACKET_A, PACKET_B, PACKET_C };

    uint8_t packetType;
 
    union
    {
        struct PacketA
        {
            int x,y,z;
        } a;

        struct PacketB
        {
            int numElements;
            int elements[MaxElements];
        } b;

        struct PacketC
        {
            bool x;
            short y;
            int z;
        } c;
    }; 
};
</pre>

When writing the packet, set the first byte in the packet to the packet type number (0,1 or 2). Then depending on the packet type, memcpy the appropriate union struct into the packet. On read do the reverse: read in the first byte, then according to the packet type, copy the packet data to the corresponding struct.

It couldn’t get simpler. So why do most games avoid this approach?

The first reason is that different compilers and platforms provide different packing of structs. If you go this route you’ll spend a lot of time with __#pragma pack__ trying to make sure that different compilers and different platforms lay out the structures in memory exactly the same way. Not that it’s impossible, but it’s certainly not trivial.

The next one is endianness. Most computers are mostly <a href="https://en.wikipedia.org/wiki/Endianness#Little-endian">little endian</a> these days (Intel) but PowerPC cores are <a href="https://en.wikipedia.org/wiki/Endianness#Big-endian">big endian</a>. Historically, network data was sent over the wire in big endian format (network byte order) but there is no reason for you to follow this tradition. Modern game network protocols write in little endian order to minimize the amount of work in the common case.

But if you do need to support communication between little endian and big endian machines, the memcpy the struct in and out of the packet approach simply won’t work. At minimum you need to write a function to swap bytes between host and network byte order on read and write for each variable in your struct.

There are other issues as well. If a struct contains pointers you can’t just serialize that value over the network and expect a valid pointer on the other side. Also, if you have variable sized structures, such as an array of 32 elements, but most of the time it’s empty or only has a few elements, it's wasteful to always send the array at worst case size. A better approach would support a variable length encoding that only sends the actual number of elements in the array.

Ultimately, the issue that really drives a stake into the heart of this approach is __security__.

It’s a _massive_ security risk to take data coming in over the network and trust it, and that's exactly what you do if you just copy a block of memory sent over the network into your struct. Wheee! What if somebody constructs a malicious packet and sends it to you with 0xFFFFFFFF in the __numElements__ of __PacketB__ causing you to trash all over memory when you process that packet?

You should, no you _must_, at minimum do some sort of per-field checking that values are in range vs. blindly accepting what is sent to you. This is why the memcpy struct approach is rarely used in professional games.

## Read and Write Functions

The next level of sophistication is read and write functions per-packet.

Start with the following simple operations:

<pre>void WriteInteger( Buffer &amp; buffer, uint32_t value );
void WriteShort( Buffer &amp; buffer, uint16_t value );
void WriteChar( Buffer &amp; buffer, uint8_t value );

uint32_t ReadInteger( Buffer &amp; buffer );
uint16_t ReadShort( Buffer &amp; buffer );
uint8_t ReadByte( Buffer &amp; buffer );
</pre>

These operate on a buffer structure which keeps track of the current position in the packet:

<pre>struct Buffer
{
    uint8_t * data;     // pointer to buffer data
    int size;           // size of buffer data (bytes)
    int index;          // index of next byte to be read/written
};</pre>

The write integer function looks something like this:

<pre>void WriteInteger( Buffer &amp; buffer, uint32_t value )
{
    assert( buffer.index + 4 &lt;= size );
#ifdef BIG_ENDIAN
    *((uint32_t*)(buffer.data+buffer.index)) = bswap( value ); 
#else // #ifdef BIG_ENDIAN
    *((uint32_t*)(buffer.data+buffer.index)) = value; 
#endif // #ifdef BIG_ENDIAN
    buffer.index += 4;
}</pre>

And the read integer function looks like this:

<pre>uint32_t ReadInteger( Buffer &amp; buffer )
{
    assert( buffer.index + 4 &lt;= size );
    uint32_t value;
#ifdef BIG_ENDIAN
    value = bswap( *((uint32_t*)(buffer.data+buffer.index)) );
#else // #ifdef BIG_ENDIAN
    value = *((uint32_t*)(buffer.data+buffer.index));
#endif // #ifdef BIG_ENDIAN
    buffer.index += 4;
    return value;
}</pre>

Now, instead of copying across packet data in and out of structs, implement read and write functions for each packet type:
<pre>struct PacketA
{
    int x,y,z;

    void Write( Buffer &amp; buffer )
    {
        WriteInteger( buffer, x );
        WriteInteger( buffer, y );
        WriteInteger( buffer, z );
    }

    void Read( Buffer &amp; buffer )
    {
        ReadInteger( buffer, x );
        ReadInteger( buffer, y );
        ReadInteger( buffer, z ); 
    }
};

struct PacketB
{
    int numElements;
    int elements[MaxElements];

    void Write( Buffer &amp; buffer )
    {
        WriteInteger( buffer, numElements );
        for ( int i = 0; i &lt; numElements; ++i )
            WriteInteger( buffer, elements[i] );
    }

    void Read( Buffer &amp; buffer )
    {
        ReadInteger( buffer, numElements );
        for ( int i = 0; i &lt; numElements; ++i )
            ReadInteger( buffer, elements[i] );
    }
};

struct PacketC
{
    bool x;
    short y;
    int z;

    void Write( Buffer &amp; buffer )
    {
        WriteByte( buffer, x );
        WriteShort( buffer, y );
        WriteInt( buffer, z );
    }

    void Read( Buffer &amp; buffer )
    {
        ReadByte( buffer, x );
        ReadShort( buffer, y );
        ReadInt( buffer, z );
    }
};</pre>

When reading and writing packets, start the packet with a byte specifying the packet type via ReadByte/WriteByte, then according to the packet type, call the read/write on the corresponding packet struct in the union.

This is real progress. Now we have a system that allows machines with different endianness to communicate <em><span style="text-decoration: underline;">and</span></em> supports variable length encoding of elements within structures.

## Bitpacking

So far we have been reading and writing packets at the byte level.

But if we have a value in the range [0,1000] we really only need 10 bits to represent all possible values. Wouldn't it be nice if we could write just 10 bits, instead of rounding up to 16?

It would be really nice if we could send boolean values using only one bit, instead of a byte.

One way to implement this is to manually organize your C++ structures into packed integers with bitfields and union tricks, such as grouping all bools together into one integer type via union and serializing them as a group. But this is tedious and error prone and there’s no guarantee that different C++ compilers pack bitfields in memory exactly the same way.

A much more flexible way that trades some small amount of CPU on packet read and write for convenience is a <span style="text-decoration: underline;"><strong>bitpacker</strong>
</span>. This is code that is able to read and write non-multiples of 8 bits into a buffer. To do this, it must perform a bunch of manual bit-shifting because data being written and read doesn’t correspond to any natural machine word type (byte, short or int).

## Writing Bits

Many (most?) people write bitpackers that work at the byte level. This means they flush bytes to memory as they are filled. This is simpler to code, but the ideal is to read and write words at a time, because modern machines are optimized to work this way instead of farting across a buffer at byte level like it’s 1985.

If you want to write 32 bits at a time, you'll need a scratch word twice that size, eg. uint64_t. The reason is that you need the top half for overflow. For example, if you have just written a value 30 bits long into the scratch buffer, then write another value that is 10 bits long you need somewhere to store 30 + 10 = 40 bits, at least until you flush the top 32 bits out to memory.

We’re going to work at the 32 bit word level, so the bitpacker state for write looks something like this:
<pre>uint64_t scratch;
int scratch_bits;
int word_index;
uint32_t * buffer;</pre>
When we start writing with the bitpacker, all these variables are cleared to zero except <strong>buffer</strong> which points to the start of the packet we are writing to. Because we're accessing this packet data at a word level, not byte level, make sure packet buffers lengths are a multiple of 4 bytes.

Let’s say we want to write 3 bits followed by 10 bits, then 24. Our goal is to pack this tightly in the scratch buffer and flush that out to memory, 32 bits at a time. Note that 3 + 10 + 24 = 37. We have to handle this case where the total number of bits don’t evenly divide into 32. This is actually the <em><span style="text-decoration: underline;">common case</span></em>.

At the first step, write the 3 bits to <strong>scratch</strong> like this:
<pre>xxx</pre>
<strong>scratch_bits</strong> is now 3.

Next, write 10 bits:

<pre>yyyyyyyyyyxxx</pre>
<strong>scratch_bits</strong> is now 13 (3+10).

Next write 24 bits:

<pre>zzzzzzzzzzzzzzzzzzzzzzzzyyyyyyyyyyxxx</pre>
<strong>scratch_bits</strong> is now 37 (3+10+24). We’re straddling the 32 bit word boundary in our 64 bit <strong>scratch</strong> variable and have 5 bits in the upper 32 bits (overflow). Flush the lower 32 bits of <strong>scratch</strong> to memory, advance <strong>word_index</strong> by one, shift <strong>scratch</strong> right by 32 and subtract 32 from <strong>scratch_bits.</strong>

<strong>scratch</strong> now looks like this:
<pre>zzzzz</pre>
We've finished writing bits but we still have data in scratch that's not flushed to memory yet. It's important to remember to manually flush any remaining bits in <strong>scratch</strong> to memory at the end of write.

When we flush a word to memory it is converted to little endian byte order. To see why this is important consider what happens if we flush bytes to memory in big endian order:
<pre>DCBA000E</pre>
Since we fill bits in the word from right to left, the last byte in the packet E is actually on the right. If we try to send this buffer in a packet of 5 bytes (the actual amount of data we have to send) the packet catches 0 for the last byte instead of E. <span style="text-decoration: underline;">Ouch</span>.

But when we write to memory in little endian order, bytes are reversed back out in memory like this:
<pre>ABCDE000</pre>
And we can write 5 bytes to the network and catch E at the end. Et voilà!
<h2>Reading Bits</h2>
To read the bitpacked data, start with the buffer sent over the network:
<pre>ABCDE</pre>
The bit reader has the following state:
<pre>uint64_t scratch;
int scratch_bits;
int total_bits;
int num_bits_read;
int word_index;
uint32_t * buffer;</pre>
To start all variables are cleared to zero except <strong>total_bits</strong> which is set to the size of the packet in bytes * 8, and <strong>buffer </strong>which points to the start of the packet.

The user requests a read of 3 bits. Since <strong>scratch_bits</strong> is zero, it’s time to read in the first word. Take that word and stash it in <strong>scratch</strong>, shifted left by <strong>scratch_bits</strong> (which is zero…). Add 32 to <strong>scratch_bits</strong>.

Now read the first 3 bits by copying <strong>scratch</strong> off to another variable and masking &amp; ( (1&lt;&lt;3 ) – 1 ), giving the value of:
<pre>xxx</pre>
Shift <strong>scratch</strong> to the right 3 bits and subtract 3 from <strong>scratch_bits</strong>:
<pre>zzzzzzzzzzzzzzzzzzzyyyyyyyyyy</pre>
Read off another 10 bits in the same way. Scratch now looks like:
<pre>zzzzzzzzzzzzzzzzzzz</pre>
The next read asks for 24 bits but <strong>scratch_bits</strong> is only 19 (=32-10-3).

It’s time to read in the next word. Or the work from memory into <strong>scratch</strong> after shifting left by <strong>scratch_bits</strong> (19). Now we have all the bits necessary for z in <strong>scratch</strong>:
<pre>zzzzzzzzzzzzzzzzzzzzzzzz</pre>
Read off 24 bits and shift <strong>scratch</strong> right by 24. s<strong>cratch</strong> is now all zeros. We're done.

## Beyond Bitpacking

Bitpackers are an excellent optimization compared with reading and writing at a byte level, but reading and writing integer values into a packet by specifying the number of bits to read/write is not the most user friendly interface possible.

Consider this example:

<pre>const int MaxElements = 32;

struct PacketB
{
    int numElements;
    int elements[MaxElements];

    void Write( BitWriter &amp; writer )
    {
        WriteBits( writer, numElements, 6 );
        for ( int i = 0; i &lt; numElements; ++i )
            WriteBits( writer, elements[i] );
    }

    void Read( BitReader &amp; reader )
    {
        ReadBits( reader, numElements, 6 );
        for ( int i = 0; i &lt; numElements; ++i )
            ReadBits( reader, elements[i] );
    }
};</pre>

This code looks fine at first glance, but let’s assume that some time later you, or somebody else on your team, increases <strong>MaxElements</strong> from 32 to 200 but forgets to update the number of bits required to <strong>7</strong>. Now the high bit of <strong>numElements</strong> are being silently truncated on send. It's pretty hard to track something like this down after the fact.

The simplest option is to just turn it around and define the maximum number of elements in terms of the number of bits sent:

<pre>const int MaxElementBits = 7;
const int MaxElements = ( 1 &lt;&lt; MaxElementBits ) - 1;</pre>

Another option is to get fancy and work out the number of bits required at compile time:

<pre>template &lt;uint32_t x&gt; struct PopCount
{
    enum { a = x - ( ( x &gt;&gt; 1 ) &amp; 0x55555555 ),
           b = ( ( ( a &gt;&gt; 2 ) &amp; 0x33333333 ) + ( a &amp; 0x33333333 ) ),
           c = ( ( ( b &gt;&gt; 4 ) + b ) &amp; 0x0f0f0f0f ),
           d = c + ( c &gt;&gt; 8 ),
           e = d + ( d &gt;&gt; 16 ),
    result = e &amp; 0x0000003f }; 
};

template &lt;uint32_t x&gt; struct Log2
{
    enum { a = x | ( x &gt;&gt; 1 ),
           b = a | ( a &gt;&gt; 2 ),
           c = b | ( b &gt;&gt; 4 ),
           d = c | ( c &gt;&gt; 8 ),
           e = d | ( d &gt;&gt; 16 ),
           f = e &gt;&gt; 1,
    result = PopCount&lt;f&gt;::result };
};

template &lt;int64_t min, int64_t max&gt; struct BitsRequired
{
    static const uint32_t result = 
        ( min == max ) ? 0 : ( Log2&lt;uint32_t(max-min)&gt;::result + 1 );
};

#define BITS_REQUIRED( min, max ) BitsRequired&lt;min,max&gt;::result</pre>
Now you can’t mess up the number of bits, and you can specify non-power of two maximum values and it everything works out.

<pre>
const int MaxElements = 32;
const int MaxElementBits = BITS_REQUIRED( 0, MaxElements );
</pre>

But be careful when array sizes aren't a power of two, because within the value serialized over the network lies the opportunity for an attacker to construct a packet that makes you trash memory!

In the example above <strong>MaxElements</strong> is 32, so <strong>MaxElementBits</strong> is 6. This seems fine because all valid values for <strong>numElements:</strong> [0,32] fit in 6 bits. The problem is that there are <span style="text-decoration: underline;">also</span> additional values within 6 bits that are <em><span style="text-decoration: underline;">outside</span></em> our array bounds: [33,63]. An attacker can use this fact to construct a malicious packet containing one of these values to make us trash memory.

This leads to the <span style="text-decoration: underline;">inescapable</span> conclusion that it’s not enough to just specify the number of bits required when reading and writing a value, we must instead specify its valid range: [min,max]. This way if a value is outside of the expected range we can detect that and abort packet read.

I’ve implemented this abort using C++ exceptions in the past, but when I profiled this code, I found it to be incredibly slow. In my experience, it’s much faster to take one of two approaches: set a flag on the bit reader that it should abort, or return false from read functions on failure. But now, in order to be completely safe on read you must to check this flag or return code on every read operation otherwise it’s possible to get stuck in a memory trashing loop.

<pre>
const int MaxElements = 32;
const int MaxElementBits = BITS_REQUIRED( 0, MaxElements );

struct PacketB
{
    int numElements;
    int elements[MaxElements];

    void Write( BitWriter &amp; writer )
    {
        WriteBits( writer, numElements, MaxElementBits );
        for ( int i = 0; i &lt; numElements; ++i )
        {
            WriteBits( writer, elements[i], 32 );
        }
    }

    void Read( BitReader &amp; reader )
    {
        ReadBits( reader, numElements, MaxElementBits );
        
        if ( numElements &gt; MaxElements )
        {
            reader.Abort();
            return;
        }
        
        for ( int i = 0; i &lt; numElements; ++i )
        {
            if ( reader.IsOverflow() )
                break;

            ReadBits( buffer, elements[i], 32 );
        }
    }
};
</pre>

If you miss any of these checks, you expose yourself to buffer overflows and infinite loops when reading packets. Clearly you don’t want this to be a manual step when writing a packet read function. It's too important to leave open to programmer error. <span style="text-decoration: underline;">You want it to be automatic</span>.

Stay tuned for the next article where I show you a really neat way to do this in C++.

<h2>Next Article: <a href="http://gafferongames.com/building-a-game-network-protocol/serialization-strategies/">Serialization Strategies</a></h2>
In the next article, I show you how to unify read and write operations into a single “Serialize” function that handles read and write at the same time without any extra runtime cost.

Please <a href="https://www.patreon.com/gafferongames">support my writing on patreon</a>, and I’ll write new articles faster, plus you get access to example source code for this article under the BSD 3-clause open source licence. <strong>Thanks for your support!</strong>

<a href="http://www.patreon.com/gafferongames"><img src="http://i0.wp.com/gafferongames.com/wp-content/uploads/2014/12/donate.png" alt="" /></a>
