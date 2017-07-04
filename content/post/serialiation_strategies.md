+++
categories = ["Building a Game Network Protocol"]
tags = ["networking"]
date = "2016-09-04"
title = "Serialization Strategies"
description = "Smart tricks that unify packet read and write"
draft = true
+++

## Introduction

Hi, I'm Glenn Fiedler and welcome to __Building a Game Network Protocol__.

In the [previous article](/post/reading_and_writing_packets/), we created a bitpacker but it required manual checking to make sure reading a packet from the network is safe. This is a real problem because the stakes are particularly high. A single missed check creates a vulnerability that an attacker can use to crash your server.

In this article, we're going to transform the bitpacker into a system where this checking is automatic. If we read past the end of a packet, the packet read will abort automatically. If a value comes in over the network that's outside of the expected range, that packet will be dropped.

We're going to do this with minimal runtime overhead, and in such a way that we don't have to code separate read and write functions anymore, performing both read _and_ write with a single function.

This is called a _serialize function_.

## Serializing Bits

Let's start with the goal. Here's where we want to end up:

<pre>
struct PacketA
{
    int x,y,z;

    template &lt;typename Stream&gt; bool Serialize( Stream &amp; stream )
    {
        serialize_bits( stream, x, 32 );
        serialize_bits( stream, y, 32 );
        serialize_bits( stream, z, 32 );
        return true;
    }
};
</pre>

Here you can see a simple serialize function. We serialize three integer variables x,y,z with 32 bits each. Straightforward.

<pre>
struct PacketB
{
    int numElements;
    int elements[MaxElements];

    template &lt;typename Stream&gt; bool Serialize( Stream &amp; stream )
    {
        serialize_int( stream, numElements, 0, MaxElements );
        for ( int i = 0; i &lt; numElements; ++i )
        {
            serialize_bits( buffer, elements[i], 32 );
        }
        return true;
    }
};
</pre>

And now something more complicated. We serialize a variable length array, making sure that the array length is in the range [0,MaxElements].

Here we serialize a rigid body with an optimization while it's at rest, writing only one bit in place of linear and angular velocity:

<pre>
struct RigidBody
{
    vec3f position;
    quat4f orientation;
    vec3f linear_velocity;
    vec3f angular_velocity;

    template &lt;typename Stream&gt; bool Serialize( Stream &amp; stream )
    {
        serialize_vector( stream, position );
        serialize_quaternion( stream, orientation );
        bool at_rest = Stream::IsWriting ? ( velocity.length() == 0 ) : 1;
        serialize_bool( stream, at_rest );
        if ( !at_rest )
        {
            serialize_vector( stream, linear_velocity );
            serialize_vector( stream, angular_velocity );
        }
        else if ( Stream::IsReading )
        {
            linear_velocity = vec3f(0,0,0);
            angular_velocity = vec3f(0,0,0);
        }
        return true;
    }
};
</pre>

Notice how we're able to branch on Stream::IsWriting and Stream::IsReading to write code for each case. These branches are removed by the compiler when specialized read and write serialize functions are generated.

As you can see, serialize functions are flexible and expressive. They're also _safe_, with each __serialize_*__ call performing checks and aborting read if anything is wrong (eg. a value out of range, going past the end of the buffer). Most importantly, this checking is automatic, _so you can't forget to do it!_

## Implementation

The trick to making this all work is to create two stream classes that share the same interface: __ReadStream__ and __WriteStream__.

The write stream implementation _writes values out_ to the buffer:

<pre>
class WriteStream
{
public:

    enum { IsWriting = 1 };
    enum { IsReading = 0 };

    WriteStream( uint8_t * buffer, int bytes ) : m_writer( buffer, bytes ) {}

    bool SerializeInteger( int32_t value, int32_t min, int32_t max )
    {
        assert( min < max );
        assert( value >= min );
        assert( value <= max );
        const int bits = bits_required( min, max );
        uint32_t unsigned_value = value - min;
        m_writer.WriteBits( unsigned_value, bits );
        return true;
    }

    // ...

private:

    BitWriter m_writer;
};
</pre>

And the read stream implementation _reads values in_:

<pre>
class ReadStream
{
public:

    enum { IsWriting = 0 };
    enum { IsReading = 1 };

    ReadStream( const uint8_t * buffer, int bytes ) : m_reader( buffer, bytes ) {}

    bool SerializeInteger( int32_t & value, int32_t min, int32_t max )
    {
        assert( min < max );
        const int bits = bits_required( min, max );
        if ( m_reader.WouldReadPastEnd( bits ) )
            return false;
        uint32_t unsigned_value = m_reader.ReadBits( bits );
        value = (int32_t) unsigned_value + min;
        return true;
    }

    // ...

private:

    BitReader m_reader;
};
</pre>

With the magic of C++ templates, we leave it up to the compiler to specialize the serialize function to the stream class passed in, producing optimized read and write functions.

To handle safety __serialize_*__ calls are not actually functions at all. They're actually macros that return false on error, thus unwinding the stack in case of error, without the need for exceptions. 

For example, this macro serializes an integer in a given range:

<pre>
#define serialize_int( stream, value, min, max )                    \
    do                                                              \
    {                                                               \
        assert( min &lt; max );                                        \
        int32_t int32_value;                                        \
        if ( Stream::IsWriting )                                    \
        {                                                           \
            assert( value &gt;= min );                                 \
            assert( value &lt;= max );                                 \
            int32_value = (int32_t) value;                          \
        }                                                           \
        if ( !stream.SerializeInteger( int32_value, min, max ) )    \
        {                                                           \
            return false;                                           \
        }                                                           \
        if ( Stream::IsReading )                                    \
        {                                                           \
            value = int32_value;                                    \
            if ( value &lt; min || value &gt; max )                       \
                return false;                                       \
        }                                                           \
     } while (0)
</pre>

A single value read outside the expected range, or a read that would go past the end of the buffer returns false and aborts the packet read.

## Serializing Floating Point Values

Consider a floating point number. In memory it's just a 32 bit value like any other. The C++ language lets us work with this fundamental property, allowing us to directly access the bits of float value as if it were an integer value:

<pre>
union FloatInt
{
    float float_value;
    uint32_t int_value;
};

FloatInt tmp;
tmp.float_value = 10.0f;
printf( "float value as an integer: %x\n", tmp.int_value );
</pre>

You can also do this with an aliased uint32_t* pointer, however I've had this break with GCC -O2, so I prefer the union trick instead. Friends of mine point out that the only _truly standard way_ to get the float as an integer is to cast a pointer to the float value to char* and reconstruct the integer from the bytes values accessed through the char pointer.

Meanwhile in the past 5 years I've had no actual problems in the field with the union trick. Here's how I use it to serialize an uncompressed float value:

<pre>
template &lt;typename Stream&gt; 
bool serialize_float_internal( Stream &amp; stream, 
                               float &amp; value )
{
    union FloatInt
    {
        float float_value;
        uint32_t int_value;
    };
    FloatInt tmp;
    if ( Stream::IsWriting )
    {
        tmp.float_value = value;
    }
    bool result = stream.SerializeBits( tmp.int_value, 32 );
    if ( Stream::IsReading )
    {
        value = tmp.float_value;
    }
    return result;
}
</pre>

This is wrapped with a __serialize_float__ macro for error checking on read.

<pre>
#define serialize_float( stream, value )                             \
  do                                                                 \
  {                                                                  \
    if ( !serialize_float_internal( stream, value ) )                \ 
        return false;                                                \
  } while (0)
</pre>

But sometimes you don't need to transmit a floating point value with full precision. You might know for a particular varue its range is [-10.0,+10.0] and an acceptable precision is 0.01. How can you compress this value so it uses less bits?

This can be done by convert that floating point value to an integer value that starts at 0 and finishes at an integer value that represents the floating point number according to the desired precision. You send this integer representation over the network and convert it back to a float on the other side.

Here's how it's done:

<pre>
template &lt;typename Stream&gt; 
bool serialize_compressed_float_internal( Stream &amp; stream, 
                                          float &amp; value, 
                                          float min, 
                                          float max, 
                                          float res )
{
    const float delta = max - min;
    const float values = delta / res;
    const uint32_t maxIntegerValue = (uint32_t) ceil( values );
    const int bits = bits_required( 0, maxIntegerValue );
    uint32_t integerValue = 0; 
    if ( Stream::IsWriting )
    {
        float normalizedValue = 
            clamp( ( value - min ) / delta, 0.0f, 1.0f );
        integerValue = (uint32_t) floor( normalizedValue * 
                                         maxIntegerValue + 0.5f );
    }
    if ( !stream.SerializeBits( integerValue, bits ) )
    {
        return false;
    }
    if ( Stream::IsReading )
    {
        const float normalizedValue = 
            integerValue / float( maxIntegerValue );
        value = normalizedValue * delta + min;
    }
    return true;
}
</pre>

Similarly, we wrap this with a __serialize_compressed_float__ macro for error checking:

<pre>
#define serialize_compressed_float( stream, value, min, max )        \
  do                                                                 \
  {                                                                  \
    if ( !serialize_float_internal( stream, value, min, max ) )      \ 
        return false;                                                \
  } while (0)
</pre>

The basic interface is complete. We can now serialize compressed and uncompressed floating point values over the network.

# Serializing Vectors and Quaternions

Once you can serialize float values it's trivial extend to serialize vectors over the network. I use a modified version of the <a href="https://github.com/scoopr/vectorial">vectorial library</a> in my projects and I implement serialization for its vector types like this:

<pre>
template &lt;typename Stream&gt; 
bool serialize_vector_internal( Stream &amp; stream, 
                                vec3f &amp; vector )
{
    float values[3];
    if ( Stream::IsWriting )
        vector.store( values );
    serialize_float( stream, values[0] );
    serialize_float( stream, values[1] );
    serialize_float( stream, values[2] );
    if ( Stream::IsReading )
        vector.load( values );
    return true;
}

#define serialize_vector( stream, value )                       \
 do                                                             \
 {                                                              \
     if ( !serialize_vector_internal( stream, value ) )         \
         return false;                                          \
 }                                                              \
 while(0)
</pre>

If your vector is bounded in some range, then you can compress it:

<pre>
template &lt;typename Stream&gt; 
bool serialize_compressed_vector_internal( Stream &amp; stream, 
                                           vec3f &amp; vector,
                                           float min,
                                           float max,
                                           float res )
{
    float values[3];
    if ( Stream::IsWriting )
    {
        vector.store( values );
    }
    serialize_compressed_float( stream, values[0], min, max, res );
    serialize_compressed_float( stream, values[1], min, max, res );
    serialize_compressed_float( stream, values[2], min, max, res );
    if ( Stream::IsReading )
    {
        vector.load( values );
    }
    return true;
}
</pre>

Notice how we build more complex serialization primitives built on top of the primitives we're already created. You can easily extend the serialization to support any type you need.

## Serializing Strings and Arrays

What if you need to serialize a string over the network?

Is it a good idea to send a string over the network with null termination? Not really. You're just asking for trouble! Instead, treat the string as an array of bytes with length prefixed. Therefore, in order to send a string over the network, we have to work out how to efficiently send an array of bytes.

First observation: why waste effort bitpacking an array of bytes into your bit stream just so they are randomly shifted by shifted by [0,7] bits? Why not just align to byte so you can memcpy the array of bytes directly into the packet? In theory, this should be much faster than bitpacking one byte at a time.

To align a bitstream to byte just work out your current bit index in the stream and how many bits are left to write until the current bit number in the bit stream divides evenly into 8, then insert that number of padding bits. 

For bonus points, pad up with zero bits to add entropy so that on read you can verify that yes, you are reading a byte align and yes, it is indeed padded up with zero bits to the next whole byte bit index. If a non-zero bit is discovered in the pad bits, _abort serialize read and discard the packet_.

Here's my code to align a bit stream to byte:

<pre>
void BitWriter::WriteAlign()
{
    const int remainderBits = m_bitsWritten % 8;
    if ( remainderBits != 0 )
    {
        uint32_t zero = 0;
        WriteBits( zero, 8 - remainderBits );
        assert( ( m_bitsWritten % 8 ) == 0 );
    }
}

bool BitReader::ReadAlign()
{
    const int remainderBits = m_bitsRead % 8;
    if ( remainderBits != 0 )
    {
        uint32_t value = ReadBits( 8 - remainderBits );
        assert( m_bitsRead % 8 == 0 );
        if ( value != 0 )
            return false;
    }
    return true;
}

#define serialize_align( stream )           \
  do                                        \
  {                                         \
      if ( !stream.SerializeAlign() )       \
          return false;                     \
  } while (0)
</pre>

Now we use this align operation to write an array of bytes into the bit stream efficiently. The only wrinkle is because the bit reader and bit writer work at the word level, so it's neccessary to have special code to handle the head and tail portion of the byte array. Because of this, the code is quite complex and is omitted for brevity. You can find it in the [sample code](https://www.patreon.com/gafferongames) for this article.

The end result is a __serialize_bytes__ primitive that we can use to serialize a string as its length followed by the string data like so:

<pre>
template &lt;typename Stream&gt; 
bool serialize_string_internal( Stream &amp; stream, 
                                char* string, 
                                int buffer_size )
{
    uint32_t length;
    if ( Stream::IsWriting )
    {
        length = strlen( string );
        assert( length &lt; buffer_size - 1 );
    }
    serialize_int( stream, length, 0, buffer_size - 1 );
    serialize_bytes( stream, (uint8_t*)string, length );
    if ( Stream::IsReading )
        string[length] = '\0';
}

#define serialize_string( stream, string, buffer_size )              \
do                                                                   \
{                                                                    \
    if ( !serialize_string_internal( stream,                         \
                                     string, buffer_size ) )         \
        return false;                                                \
} while (0)
</pre>

This is an idea format because it lets us quickly reject malicious string data, vs. having to read to the end of the packet data looking for '\0' before giving up. This is important because sometimes attacks are simply designed to degrade your server by making it do work, vs. crashing it immediately.

## Serializing Array Subsets

When implemeting a game network protocol, sooner or later you need to serialize an array of objects over the network. Perhaps the server needs to send all objects down to the client, or an array of events or messages to be sent. 

This is straightforward if you are sending _all_ objects in the array down to the client, but what if you want to send only a subset of the array?

The first and simplest approach is to iterate across all objects in the array and serialize a bool per-object if that object is to be sent. If the value of that bool is 1 then the object data follows, otherwise it's ommitted and the bool for the next object is up next in the stream.

<pre>
template &lt;typename Stream&gt; 
bool serialize_scene_a( Stream &amp; stream, Scene &amp; scene )
{
    for ( int i = 0; i &lt; MaxObjects; ++i )
    {
        serialize_bool( stream, scene.objects[i].send );
        if ( !scene.objects[i].send )
        {
            if ( Stream::IsReading )
            {
                memset( &amp;scene.objects[i], 0, sizeof( Object ) );
            }
            continue;
        }
        serialize_object( stream, scene.objects[i] );
    }
    return true;
}
</pre>

But what if the array of objects is very large, like 4000 objects? 4000 / 8 = 500 bytes overhead, even if you only send one or two objects! That's... not good. Can we switch it around so we take overhead propertional to the number of objects sent instead of the total number of objects in the array?

We can but now, we've done something interesting. We're walking one set of objects in the serialize write (all objects in the array) and are walking over a different set of objects in the serialize read (subset of objects sent). At this point the unified serialize function concept breaks down. It's best to separate the read and write back into separate functions in cases like this:

<pre>
bool write_scene_b( protocol2::WriteStream &amp; stream, Scene &amp; scene )
{
    int num_objects_sent = 0;
    for ( int i = 0; i &lt; MaxObjects; ++i )
    {
        if ( scene.objects[i].send )
            num_objects_sent++;
    }
    write_int( stream, num_objects_sent, 0, MaxObjects );
    for ( int i = 0; i &lt; MaxObjects; ++i )
    {
        if ( !scene.objects[i].send )
        {
            continue;
        }
        write_int( stream, i, 0, MaxObjects - 1 );
        write_object( stream, scene.objects[i] );
    }
    return true;
}

bool read_scene_b( protocol2::ReadStream &amp; stream, Scene &amp; scene )
{
    memset( &amp;scene, 0, sizeof( scene ) );
    int num_objects_sent; 
    read_int( stream, num_objects_sent, 0, MaxObjects );
    for ( int i = 0; i &lt; num_objects_sent; ++i )
    {
        int index; 
        read_int( stream, index, 0, MaxObjects - 1 );
        read_object( stream, scene.objects[index] );
    }
    return true;
}
</pre>

Alternatively you could generate a separate data structure with the set of changed objects, and implement a serialize for that array of changed objects. But having to generate a C++ data structure for each data structure you want serialized is a huge pain in the ass. 

Eventually you want to walk several data structures at the same time and effectively write out a dynamic data structure to the bit stream. This is a really common thing to do when writing more advanced serialization methods like delta encoding. As soon as you do this, unified serialize no longer makes sense.

One more point. The code above walks over the set of objects _twice_ on serialize write. Once to determine the number of changed objects and a second time to actually serialize the set of changed objects. Can we do it in one pass instead? Absolutely! You can use another trick, rather than serializing the # of objects in the array up front, use a _sentinel value_ to indicate the end of the array:

<pre>
bool write_scene_c( protocol2::WriteStream &amp; stream, Scene &amp; scene )
{
    for ( int i = 0; i &lt; MaxObjects; ++i )
    {
        if ( !scene.objects[i].send )
        {
            continue;
        }
        write_int( stream, i, 0, MaxObjects );
        write_object( stream, scene.objects[i] );
    }
    write_int( stream, MaxObjects, 0, MaxObjects );
    return true;
}

bool read_scene_c( protocol2::ReadStream &amp; stream, Scene &amp; scene )
{
    memset( &amp;scene, 0, sizeof( scene ) );
    while ( true )
    {
        int index; read_int( stream, index, 0, MaxObjects );
        if ( index == MaxObjects )
        {
            break;
        }
        read_object( stream, scene.objects[index] );
    }
    return true;
}
</pre>

This works great if the set of objects sent is a small percentage of total objects. But what if a large number of objects are sent, lets say half of the 4000 objects in the scene. That's 2000 object indices with each index costing 12 bits... that's 24000 bits or 3000 bytes (almost 3k!) in your packet wasted indexing objects.

You can reduce this by encoding each object index relative to the previous object index. Think about it, we're walking left to right along an array, so object indices start at 0 and go up to MaxObjects - 1. Statistically speaking, you're quite likely to have objects that are close to each other and if the next index is +1 or even +10 or +30 from the previous one, on average, you'll need quite a few less bits to represent that difference than you need to represent an absolute index.

Here's one way to encode the object index as an integer relative to the previous object index, while spending less bits on statistically more likely values (eg. small differences between successive object indices, vs. large ones):

<pre>
template &lt;typename Stream&gt; 
bool serialize_object_index_internal( Stream &amp; stream, 
                                      int &amp; previous, 
                                      int &amp; current )
{
    uint32_t difference;
    if ( Stream::IsWriting )
    {
        assert( previous &lt; current );
        difference = current - previous;
        assert( difference &gt; 0 );
    }

    // +1 (1 bit)
    bool plusOne;
    if ( Stream::IsWriting )
       plusOne = difference == 1;
    serialize_bool( stream, plusOne );
    if ( plusOne )
    {
        if ( Stream::IsReading )
            current = previous + 1;
        previous = current;
        return true;
    }

    // [+2,5] -&gt; [0,3] (2 bits)
    bool twoBits;
    if ( Stream::IsWriting )
        twoBits = difference &lt;= 5;
    serialize_bool( stream, twoBits );
    if ( twoBits )
    {
        serialize_int( stream, difference, 2, 5 );
        if ( Stream::IsReading )
            current = previous + difference;
        previous = current;
        return true;
    }

    // [6,13] -&gt; [0,7] (3 bits)
    bool threeBits;
    if ( Stream::IsWriting )
        threeBits = difference &lt;= 13;
    serialize_bool( stream, threeBits );
    if ( threeBits )
    {
        serialize_int( stream, difference, 6, 13 );
        if ( Stream::IsReading )
            current = previous + difference;
        previous = current;
        return true;
    }

    // [14,29] -&gt; [0,15] (4 bits)
    bool fourBits;
    if ( Stream::IsWriting )
        fourBits = difference &lt;= 29;
    serialize_bool( stream, fourBits );
    if ( fourBits )
    {
        serialize_int( stream, difference, 14, 29 );
        if ( Stream::IsReading )
            current = previous + difference;
        previous = current;
        return true;
    }

    // [30,61] -&gt; [0,31] (5 bits)
    bool fiveBits;
    if ( Stream::IsWriting )
        fiveBits = difference &lt;= 61;
    serialize_bool( stream, fiveBits );
    if ( fiveBits )
    {
        serialize_int( stream, difference, 30, 61 );
        if ( Stream::IsReading )
            current = previous + difference;
        previous = current;
        return true;
    }

    // [62,125] -&gt; [0,63] (6 bits)
    bool sixBits;
    if ( Stream::IsWriting )
        sixBits = difference &lt;= 125;
    serialize_bool( stream, sixBits );
    if ( sixBits )
    {
        serialize_int( stream, difference, 62, 125 );
        if ( Stream::IsReading )
            current = previous + difference;
        previous = current;
        return true;
    }

    // [126,MaxObjects+1] 
    serialize_int( stream, difference, 126, MaxObjects + 1 );
    if ( Stream::IsReading )
        current = previous + difference;
    previous = current;
    return true;
}

template &lt;typename Stream&gt; 
bool serialize_scene_d( Stream &amp; stream, Scene &amp; scene )
{
    int previous_index = -1;
    
    if ( Stream::IsWriting )
    {
        for ( int i = 0; i &lt; MaxObjects; ++i )
        {
            if ( !scene.objects[i].send )
                continue;
            write_object_index( stream, previous_index, i );
            write_object( stream, scene.objects[i] );
        }
        write_object_index( stream, previous_index, MaxObjects );
    }
    else
    {
        while ( true )
        {
            int index; 
            read_object_index( stream, previous_index, index );
            if ( index == MaxObjects )
                break;
            read_object( stream, scene.objects[index] );
        }
    }
    return true;
}
</pre>

Notice how larger indices far apart cost more per-index than the non-relative encoding (12 bits per index). This _seems_ bad but is it really? Even if you hit the 'worst case' (objects indices spaced apart by exactly +126 apart) how many of these can you actually fit into an array 4000 large? Just 32. No worries!

## Protocol IDs, CRC32 and Serialization Checks

-- todo: fix turn

At this point you may wonder. Wow. This whole thing seems really fragile. It's a totally unattributed binary stream. A stack of cards. What if you somehow desync read and write? What if somebody just sent packets containing random bytes to your server. How long until you hit a sequence of bytes that crashes you out?

I have good news for you and the rest of the game industry since most game servers basically work this way. There are techniques you can use to reduce or virtually eliminate the possibility of corrupt data getting past the serialization layer.

The first technique is to include a protocol id in your packet. Typically, the first 4 bytes you can set to some unique value. It could be a hash of your protocol id and your protocol version number in the first 32 bits of each packet and you're doing pretty good. At least if a random packet gets sent to your port from some other application (remember UDP packets can come in from any IP/port combination at any time) you can trivially discard it:

<pre>
[protocol id] (32bits)
(packet data)
</pre>

The next level of protection is to pass a CRC32 over your packet and include that in the header. This lets you pick up corrupt packets (these do happen, remember that the IP checksum is just 16 bits, and a bunch of stuff will not get picked up by a checksum of 16bits...). Now your packet header looks ilke this:

<pre>
[protocol id] (32bits)
[crc32] (32bits)
(packet data)
</pre>

At this point you may be wincing. Wait. I have to take 8 bytes of overhead per-packet just to implement my own checksum and protocol id? Well actually, _you don't_. You can take a leaf out of how IPv4 does their checksum, and make the protocol id a _magical prefix_. eg: you don't actually send it, but if both sender and receiver knows the protocol id and the CRC32 is calculated as if the packet were prefixed by the protocol id, the CRC32 will be incorrect if the sender does not have the same protocol id as the receiver, saving 4 bytes per-packet:

<pre>
<del>[protocol id] (32bits)</del>   // not actually sent, but used to calc crc32
[crc32] (32bits)
(packet data)
</pre>

Of course CRC32 is only protection against random packet correction, and is no actual protection against a malicious sender who can easily modify or construct a malicious packet and then properly adjust the CRC32 in the first four bytes. To protect against this you need to use a more cryptographically secure hash function combined with a secret key perhaps exchanged between client and server over HTTPS by the matchmaker prior to the client attempting to connect to the game server.

One final technique, perhaps as much a check against programmer error on your part and malicious senders (although redundant once you encrypt and sign your packet) is the _serialization check_. Basically, somewhere mid-packet, either before or after a complicated serialization section, just write out a known 32 bit integer value, and check that it reads back in on the other side with the same value. If the serialize check value is incorrect _abort read and discard the packet_.

I like to do this between sections of my packet as I write them, so at least I know which part of my packet serialization has desynced read and write as I'm developing my protocol (it's going to happen no matter how hard you try to avoid it...). Another cool trick I like to use is to serialize a protocol check at the very end of the packet, this is super, super useful because it helps pick up packet truncations.

So now the packet looks something like this:

<pre>
<del>[protocol id] (32bits)</del>   // not actually sent, but used to calc crc32
[crc32] (32bits)
(packet data)
[end of packet serialize check] (32 bits)
</pre>

You can just compile these protocol checks out of your retail build if you like. Here you almost certainly have robust encryption and a packet signature, so you can replace the fragile development techniques based around CRC32 and serialization checks with their cryptographically secure equivalent.
