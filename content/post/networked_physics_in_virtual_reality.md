+++
categories = ["White papers"]
tags = ["physics", "networking", "vr"]
date = "2017-03-31"
title = "Networked Physics in Virtual Reality"
description = "Networking a stack of cubes in virtual reality with Unity and PhysX"
draft = true
+++

# Introduction

Link to my previous GDC talks on the subject

Virtual reality being interesting, but lonely. You can't move, why not have somebody else in there with you? Why not interact with a shared space?

Something about Oculus. Research etc. Thanks for sponsoring my work.

...

# The Goal

Stable stacks. Describe the goal and why it's hard.

(Link ahead to try out the demo, read on to understand how it was implemented).

Something about interaction and throwing, making tall stable stacks of cubes, players picking up objects and throwing them at stacks of cubes, throwing objects from one player to another, catching objects thrown by another player.

...

# The Problem

Latency.

Bandwidth.

Resolving conflicts.

...

# What about deterministic lockstep?

(goal of this section is to explain how deterministic lockstep could be used, and have the user understand it's not a viable approach for networking in unity w. PhysX, and perhaps in general, due to low player count).

Seemingly attractive. Low bandwidth. Send inputs only.

(Something about my discovery that the scene tends to play back the same way though, at least on my machine...)

But PhysX is not guaranteed deterministic...

When the creator of a physics library says it isn't guaranteed to be deterministic, you should listen to them.

(Also, if latency hiding is required, requires a full copy of the simulation, GGPO style, and resimulating frames.)

...

# What about client-side prediction?

(explain to the reader at a basic level how client-side prediction works, and have them understand how it breaks down when networking a physics simulation due to high cost of rollback)

FPS games. Overview of how it works.

Why it's not a good idea here:

0. Designed for players moving around a static world, interacting at a distanec (eg. FPS). => breaks down when objects interact.

1. CPU bound. Rollback non-starter with physics sim, high CPU cost.

2. Rollback would be potentially extremely jarring in VR

...

...

# What about somehow sending forces or applying forces to keep the simulation in sync?

(this is something that pisses me off, I want to explain how it breaks down for stacks, and how it doesn't work well when objects don't receive an update every frame).

# What could a solution look like?

(reader should understand the restriction to coop only provides a way to solve this problem without the high CPU cost of rollback, at the cost of security.)

Idea of distributing the world to hide. One player takes ownership of objects they interact with, sends state of those objects to other players.

Authority scheme.

(reader should understand this comes at the cost of security. coop only.)

...

# State Synchronization

(reader should understand concept of running simulation on both sides, and synchronizing state from left -> right to keep the scene in sync, even though it is not perfectly deterministic).

(Start with stack of cubes that fall from an initial configuration, create two instances of the world "host" and "guest").

Flow in one direction: host -> guest.

Loopback scene. Benefits of working this way. Fast iteration time.

# Quantized State

(reader should understand that sending uncompressed physics data is too expensive, that compression for physics data over the network is *lossy*, and that if we want the extrapolation to match the original simulation as closely as possible (and we do for stable stacks), then it is necessary to quantize on both sides. This is a *key* technique that makes stable stacks possible).

Bandwidth used so far. With floating point it's a lot.

Want to reduced bandwidth.

Basic compression options:

 - at rest flag
 - bound and quantize position
 - bound and quantize linear and angular velocity
 - smallest 3 quaternion

But also want good extrapolation on the other side, ideally, extrapolate the same way as the local sim it was sent from.

But the quantization slightly affects the simulation...

What's the solution?

Quantize on _both sides_.

Describe how it works.

(reader should understand that the quantization is actually quite expensive, PhysX doesn't particularly like the state being quantized and fed back in like this. If physics engine creators could change how their engines work to work better with this concept of state being quantized each frame, or if a custom physics engine was designed around quantizing it's probably possible to reduce this cost)

(however, it's necessary for truly stable stacks in the remote view)

...

# Coming to Rest

(reader should understand that quantizing the simulation at the start of each frame creates error, )

(important point: PhysX minimum depenetration velocity set on rigid body, eases objects out of penetration over time, rather than immediately. without this, objects jitter due to penetration induced by quantization).

Stacks, slight penetration. Errors due to linear quantization, but especially due to quantization of angle.

No guarantee that a smallest 3 representation is able to exactly represent for example a cube at every angle around the y axis, while still being perfectly flat, eg. one edge or vertex slightly penetrating.

(good opportunity for a diagram here, show cube resting on another cube, and then slight penetration, with arrow for being pushed out)

Breaks the built in at rest.

video: slight jitter

Problem, because we need stable stacks. Can't have jitter like this. Objects must come to rest and stick to be stable.

(possible video showing sloppy at rest causig sliding of objects vs. sticking in stacks when they fall?)

Solution: disable built in at rest calculation, implement custom at rest calculation.

Ring buffer. Based around quantized state. If position or rotation don't change significantly (within quantization resolution), over a number of frames, force object to rest.

video: stable at rest.

...

# Priority Accumulator

(reader should understand that sending all objects every frame may not fit into bandwidth budget, even with quantized state, especially when a lot of objects are changing. the way to solve this is to send only a subset of cube states in each packet, and use a priority accumulator to work out which updates to send each frame. this way updates are distributed fairly across 

Recent high velocity impact boost. Check over priority function for anything more interesting. perhaps mention -1 priority accumulator value meaning, don't send this object.

...

# Reliability

(reader should understand the sort of reliability we are looking for is, "which packets did the other side receive?" and that the basic packet header lets us transmit acks back to the server for a steading stream of packets, eg. 60HZ, 90HZ over UDP, even when packet loss exists, by sending each ack redundantly.)

(reader should understand that this is quite different to how TCP implements reliability, because we're not trying to resend lost packets, we're just trying to work out which packets got through and which didn't. this allows us to intellently construct packets with data that we know got through, and avoid resending data that we know did get through).

# Delta Encoding

(reader should understand two different ways to do delta encoding, the first is frame based, where the entire frame is encoded relative to a previous frame, which is reasonably simple, the other is the method we use here, where the sender needs to track per-object what the most recent update it received was, if any, so future updates can be encoded relative to the most recent update the other side received for each object. this has to work even under packet loss, and has to work on join, where the other side hasn't received any state for objects yet).

Need to encode relative to previous state.

Delta buffer concept. 

Describe delta buffer data structure and how it works.

...

# Delta Not Changed

(reader should understand that sending cubes at rest over and over is wasteful, because the state value is the same. if we are able to encode simply, this object has not changed relative to the previous state, we can encode that common case with just one bit, 'not changed').

interesting aside, we can't just stop sending at rest objects, because the simulation runs on both sides, so an at rest cube may be pushed by another cube and need to have the state sent again, otherwise it desyncs. in fact we can't eve send at rest cubes less frequently, all we can really do is encode them efficiently when they are sent.)

...

# Delta Difference

...

# Delta Prediction

linear prediction worked great.

fixed point math required.

(gave up predicting rotation, smallest 3 linear instability, would not compress and reconstruct to the same values reliabily, if it doesn't decompress to same values, then it's not a good representation for encoding delta).

...

# Limits of Delta Compression

(reader should understand that entropy exists, and there is a limit to how much compression can be applied. no matter what I did, the big stack when they all fell was expensive, because it had a lot of very random collisions and interactions at high speed, so it was a worst case. however, the majority of common cases were extremely efficient past that point, eg. thrown objects predicted ballistic trajectory and almost zero cost, stationary cubes almost zero cost, slowly moving objects almost zero cost etc.)

Graph of bandwidth savings.

Common case great. Initial drop of all the cubes at the start, so random, not much I can do to improve, no matter how hard I try to delta encode.

Show some cool graphs.

...

------

(Kindof almost feels like a part 2 here... at least there needs to be a turn...)

# Interactivity

Grab, throw, stacking etc.

    - layers, making cube not physical while held, big part of believability of interactions, counterintuitive.

Throwing vs. placing.

    - inheriting velocity for throwing vs. stacking.

Rotate, zoom, snap to hand.

Concept of ownership vs. authority.

Thrown objects, hitting objects, stacking.

Walking Interactions

(Recursive walk interacting objects, transmit authority).

(Return to color at rest for a period of time).

(Interesting notes, pulling objects from under stacks, requires manually waking objects above, manual walk for objects with height above threshold of object removed. Otherwise they hang there!)

...

# Synchronizing Avatars

(reader should understand that we synchronize avatars by sending local position and rotation for head, hands, and while a cube is held by an avatar, it is synchronized as part of the avatar state, and is not sent via the regular priority accumulator state, eg. -1 priority accumulator update for that object).

...

# Client/Server

(reader should understand that the player who starts the game is the "host" and they are different to "guests" who join the game. the host arbitrates authority for all guests, the guests only care about objects they are interacting with, and other objects are sent from the host to guests).

Introduce client/server topology and how it works. Not peer-to-peer.

(Necessary to buy into concept of host/guest, because host is arbiter of authority).

(Note that host could be a separate machine, eg. dedicated server, and in fact would be a lot cleaner in this case).

...

# Conflict Resolution

(jesus this section is going to be complicated)

Boy this will be a complicated section. Might need to be broken down into sub-parts. Majority of the meat here. Holy shit.

I'm going to have to get this all back in my head. Might be tricky to do so. It's really complicated

(interaction override, eg. throwing a cube at a stack from another player, while it's their color, take over authority, key to design).

...

# Real World Networking

(What to expect over the real world, eg. why is it so jittery!)

...

# Smoothing

(reader should understand that we can apply basic smoothing by making the physical object invisible, and having a smoothed cube follow the physical object, but *not* smoothing in world space (eg. lowpass), instead, tracking the position and rotation error offsets when a network update arrives that is at a different place to the current logical position, such that this error is reduced over time, instead of visibly popping.)

good opportunity to show some videos.

(ideally, diagrams showing how I implemented it with a parented object, and then unparent in unity, and manually in LateUpdate force its position relative to parent, this is because i want the error offsets in world space, not local space. otherwise, the position error would spin around a rotating object and look non-physical).

# Jitter Buffer

(reader should understand that we can do better than just smoothing, if we implement a jitter buffer. because we don't use smoothing to fix temporaly differences, +/- 1-2 frames, but only when there is an actual difference between the two simulations, eg. a pop).

(reader should understand that the network dosen't deliver packets sent n times per-second nicely spaced apart exactly 1/n seconds, they are jittered, a bit early, a bit late. to solve this we can trade some added latency for smoothness, eg. 100ms, and store packets in a buffer, recovering them at the nice 1/n interval we want. we can also use the jitter buffer to recover avatar state at render time, which is not necessarily lined up with physics time, by storing the sample time on the sender side of the avatar state, and interpolating between the two nearest sample states in the remote view to reconstruct the avatar pose at remote view render time exactly).

(good opportunity to show videos without jitter buffer, with jitter buffer, remote avatar etc.)

(future work: jitter buffer should adapt to handle drift.)

...

# Future Work

(interpolation in remote view, simulation rewind and rollback, possibly a subset of simulation could be rolled back only, having basically the same properties as this authority scheme, but having server authoritative physics. gain: security, loss: in cases where players interact with the same stack, or both throw an object at a stack. dedicated servers for physcis simulation, quantizing rotation to a different representation than smallest 3, eg. quantized 4, prediction of PhysX simulation including rotation)

# Conclusion

....

(Link once again to demo. Try it out yourself.)

----- 

<i>
**Glenn Fiedler** is the founder and president of [The Network Protocol Company](http://thenetworkprotocolcompany.com) where he helps clients network their games. Prior to starting his own company he was a senior programmer at Respawn Entertainment working on Titanfall 1 and 2.

Glenn is also the author of several popular series of articles on game networking and physics at [gafferongames.com](http://www.gafferongames.com), and is the author of the open source network libraries [libyojimbo](http://www.libyojimbo.com) and [netcode.io](http://netcode.io)

If you would like to support Glenn's work, you can do that on [patreon.com](http://www.patreon.com/gafferongames)
</i>
