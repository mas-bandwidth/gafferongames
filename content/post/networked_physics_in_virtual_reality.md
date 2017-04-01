+++
categories = ["White papers"]
tags = ["physics", "networking", "vr"]
date = "2017-03-31"
title = "Networked Physics in Virtual Reality"
description = "Networking a stack of cubes in virtual reality with Unity and PhysX"
draft = true
+++

# Introduction

(reader should understand that I've done previous work in this area, that networked physcis in VR is inherently new and interesting, that oculus is sponsoring my work, and I'm researching networked physics in VR).

Link to my previous GDC talks on the subject

Virtual reality being interesting, but lonely. You can't move, why not have somebody else in there with you? Why not interact with a shared space?

Something about Oculus. Research etc. Thanks for sponsoring my work.

...

# The Goal

(reader should understand that the goal is a shared world experience where players can interact and pick up, throw, stack cubes, that this is difficult for many reasons, and perhaps when I started, I wasn't even sure if it could be done. understand that this was definitely a research project. can this be done? can it be made to look high quality? will it work? I'm not 100% sure but I think it might be able to be done).

(reader should really understand that the success was, two players being able to interact with the cubes and achieve stable stacks, with no latency of interaction. if the stacks were stable in the remote view, it's a win. if it looks as good as possible even better. key goal: networked stable stacks)

Stable stacks. Describe the goal and why it's hard.

(Link ahead to try out the demo, read on to understand how it was implemented).

Something about interaction and throwing, making tall stable stacks of cubes, players picking up objects and throwing them at stacks of cubes, throwing objects from one player to another, catching objects thrown by another player.

(turn: so how are we going to implement this?)

...

# What about deterministic lockstep?

(reader should understand how deterministic lockstep works, but that PhysX simulation does not guarantee determinism, so we can't use it. don't tilt at windmills. even if it was deterministic, readers should understand it's not the best approach, because latency hiding GGPO would require two copies of the simulation and a lot of resimulation of physics state in order to hide latency for local player interactions, this would be prohibitively expensive in terms of CPU).

(goal of this section is to explain how deterministic lockstep could be used, and have the user understand it's not a viable approach for networking in unity w. PhysX, and perhaps in general, due to low player count).

Seemingly attractive. Low bandwidth. Send inputs only.

(Something about my discovery that the scene tends to play back the same way though, at least on my machine...)

But PhysX is not guaranteed deterministic...

When the creator of a physics library says it isn't guaranteed to be deterministic, you should listen to them.

(Also, if latency hiding is required, requires a full copy of the simulation, GGPO style, and resimulating frames.)

...

# What about client-side prediction?

(reader should basically understand how first person shooters do client side prediction to hide local player actions, and understand that this works well in these sort of games because players move around a static world and don't tend to interact with each other, not how when players collide and bump against each other in FPS it is jittery and poorly defined. reader should understand that rolling back and rewinding a physcis simulation state is potentially extremely complex, and probably, if the whole simulation were to be rewound and resimulated, prohibitively expensive in terms of CPU).

(explain to the reader at a basic level how client-side prediction works, and have them understand how it breaks down when networking a physics simulation due to high cost of rollback)

FPS games. Overview of how it works.

Why it's not a good idea here:

0. Designed for players moving around a static world, interacting at a distanec (eg. FPS). => breaks down when objects interact.

1. CPU bound. Rollback non-starter with physics sim, high CPU cost.

2. Rollback could be potentially extremely jarring in VR

...

# What could a solution look like?

(reader should understand that if the simulation is not deterministic and rollback is too expensive, then this is probably the only option available. it's probably worth mentioning that it may be possible, to implement something that only rolls back a subset of the simulation, but because we are coop we're don't need server authoritative, this could be explored in future work).

^---- this is jumping ahead, this section should describe a solution, and how we might be willing to trade something to get it. then, show how authority scheme fits the bill in next section.

(reader should also understand the cost of this decision, the restriction to coop only provides a way to solve this problem without the high CPU cost of rollback, at the cost of security, but that also, authority schemes tend to be complex, eg. distributed programming, and difficult to reason about).

Idea of distributing the world to hide. One player takes authority of objects they interact with, sends state of those objects to other players.

Also, concept of ownership. players take ownership over objects they grab, so the player to grab an object wins. ownership wins over authority.

# Authority scheme.

^--- need to work on the split between previous paragraph and this one. they're bleeding in to each other.

(reader should see how the authority scheme satisfies the constraints)

(reader should understand the basic concepts as I envisioned them when I started work, that there is some sort of authority where you can take authroity over objects you interact with, eg. thrown objects, and a concept of ownership which is stronger, players *own* objects they are holding in their hands, authority can be overridden, eg. a stack that is blue can be turned red if a red cube is thrown at it, but ownership is firm, if you obtain ownership of an object, and the server agrees with you, you retain ownership of an objcet until you release it).

(reader should understand the idea of flow, about how non-host players can take authority over objects they interact with, and start sending state for those objects back to the host, if the host agrees that client was the first to interact with an object, then it accepts that update from the guest. flow diagrams.)

(explain in context of "host" and "guest". host sends everything by default to guest, but guest can take authority over a subset of objects, and starts sending those back to host, if host agrees, host can accept those state updates, or ignore them.)

--- 

(may need a turn here, we're basically transitioning from 'what if' to solid implementation...)

# State Synchronization

(reader should understand basic concept of state synchronization, running simulation on both sides, and synchronizing state from left -> right to keep the scene in sync, even though it is not perfectly deterministic, that we are hard snapping state, and not applying forces to try to move the remote simulation towards the update that comes in over the network, and that we do this because we need an extrapolation that matches as closely as possible to what actualyl happened, vs. an approximation, in order to obtain stable stacks).

(Start with stack of cubes that fall from an initial configuration, create two instances of the world "host" and "guest").

Flow in one direction: host -> guest.

(What about somehow sending forces or applying forces to keep the simulation in sync. this is something that pisses me off, I want to explain how it breaks down for stacks, and how it doesn't work well when objects don't receive an update every frame. reader should understand that we are applying state hard, not fudging it to try to apply forces and torques to move objects closer towards the state coming in over the network. we do this because we need stable stacks, eg. an extrapolation that matches, v.s some bullshit half-assed shit with sloppy forces trying to hold a stack together).

Loopback scene. Benefits of working this way. Fast iteration time.

# Quantized State

(reader should understand that sending uncompressed physics data is too expensive, that compression for physics data over the network is *lossy*, and that if we want the extrapolation to match the original simulation as closely as possible (and we do for stable stacks), then it is necessary to quantize on both sides. This is a *key* technique that makes stable stacks possible).

Bandwidth used so far. With floating point it's a lot. (Do some calculations.)

Want to reduce bandwidth.

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

(however, it *is* necessary for stable stacks in the remote view)

...

# Coming to Rest

(reader should understand that quantizing the simulation at the start of each frame creates error, and this error results in objects going into slight penetration with the ground and other objects while they are in stacks, this causes jitter and destabilizes stacks, and breaks the regular PhysX at rest calculation, we have to write our own replacement that works with the limits of our quantization, reader should understand how this works with a ring buffer, and is focused on actual motion, so it ignores small imperceptible jitter in position/rotation, and only case if the objcet is moving sigificantly over time across a number of frames. physcis at rest heisenberg principle).

(important point: PhysX minimum depenetration velocity set on rigid body, eases objects out of penetration over time, rather than immediately. without this, objects jitter due to penetration induced by quantization).

Stacks, slight penetration. Errors due to linear quantization, but especially due to quantization of angle.

No guarantee that a smallest 3 representation is able to exactly represent for example a cube at every angle around the y axis, while still being perfectly flat, eg. one edge or vertex slightly penetrating.

(good opportunity for a diagram here, show cube resting on another cube, and then slight penetration, with arrow for being pushed out)

Breaks the built in at rest.

video: slight jitter

(also, interesting phenomenon, at certain orientations, cubes would slide along the ground... I think it worked like this, ... diagram showing what I think was happening. crazy...)

Problem, because we need stable stacks. Can't have jitter like this. Objects must come to rest and stick to be stable.

(possible video showing sloppy at rest causig sliding of objects vs. sticking in stacks when they fall?)

Solution: disable built in at rest calculation, implement custom at rest calculation.

Ring buffer. Based around quantized state. If position or rotation don't change significantly (within quantization resolution), over a number of frames, force object to rest.

video: stable at rest.

...

# Priority Accumulator

(reader should understand that sending all objects every frame may not fit into bandwidth budget, even with quantized state, especially when a lot of objects are changing. the way to solve this is to send only a subset of cube states in each packet, and use a priority accumulator to work out which updates to send each frame. this way updates are distributed fairly across all objects in the scene).

Recent high velocity impact boost. Check over priority function for anything more interesting. perhaps mention -1 priority accumulator value meaning, don't send this object. we'll use this later.

(reader should understand that even though we are only sending a subset of objects, when all objects are falling in a big stack it's very chaotic, so there is a limit as to how infrequently we can send each cube state, and at the bandwidth target, we're not able to send each cube state frequently enough to avoid pops and jitter when the big stack falls, therefore we have to do more aggressive optimizations...)

# Reliability

(reader should understand that some sort of reliability is the first step towards these bandwidth optimizations, that UDP has packet loss, so if we want to do any advanced compression, we need to know which packets get through to the other side).

(reader should understand the sort of reliability we are looking for is, "which packets did the other side receive?" and that the basic packet header lets us transmit acks back to the server for a steading stream of packets, eg. 60HZ, 90HZ over UDP, even when packet loss exists, by sending each ack redundantly.)

(reader should understand that this is quite different to how TCP implements reliability, because we're not trying to resend lost packets, we're just trying to work out which packets got through and which didn't. this allows us to intellently construct packets with data that we know got through, and avoid resending data that we know did get through).

# Delta Encoding

(reader should understand two different ways to do delta encoding, the first is frame based, where the entire frame is encoded relative to a previous frame, which is reasonably simple, the other is the method we use here, where the sender needs to track per-object what the most recent update it received was, if any, so future updates can be encoded relative to the most recent update the other side received for each object. this has to work even under packet loss, and has to work on join, where the other side hasn't received any state for objects yet).

Need to encode relative to previous state.

Delta buffer concept. Two sides, store most recent state received, but also store history of n states that it might be encoded relative to, up to some maximum history. on the sender side, if the baseline state is too old, don't bother encoding relative and send absolute, that way it self corrects if the baseline ever gets too far behind, and we don't have to waste memory storing multiple seconds worth of history per-object).

Describe delta buffer data structure and how it works.

...

# Delta Not Changed

(reader should understand that sending cubes at rest over and over is wasteful, because the state value is exactly the same. if we are able to encode simply, 'this object has not changed relative to the previous state', we can encode that common case with just one bit, 'not changed').

interesting aside, we can't just stop sending at rest objects, because the simulation runs on both sides, so an at rest cube may be pushed by another cube and need to have the state sent again, otherwise it desyncs. in fact we can't eve send at rest cubes less frequently, all we can really do is encode them efficiently when they are sent.)

To do this we compare quantized state with most recent state in delta buffer. if the state is the same, then we send one bit, not changed.

# Delta Difference

(reader should understand that we can send the linear difference between baseline position and current position as an offset, and the same for linear and angular velocity. reader should understand that we can encode this with the 0, -1, +1, -2, +2 mapping to make compression easier, but that compressing variable sized deltas is pretty inefficient with bitpacking, and would be better compressed with arithmetic or range encoding, but it's still a win, the trick is to use the least bits for the most statistically common differences).

(reader should also understand that orientation is not delta compressed. smallest 3 representation is a poor choice of rotation representation for delta encoding, because as an object rotates you can have a different set of smallest 3 components in the quaternion, hence they're not guaranteed to always be close to each other. a different representation of rotation would be better.)

...

# Delta Prediction

(reader should understand that while a cube is moving ballistically in the air, we can predict roughly where it will be, and encode a small error relative to where its predicted future position, linear and angular velocity values would be. if the prediction is good, the difference will be smaller on average than the actual difference in the values, especially when objects are moving or rotating quickly. obviously the prediction is not going to be good if the object actually collides with something (another cube, or the ground) between the baseline and current state).

linear prediction worked great. was able to match physX calculation very closely. in many cases, the prediction was perfect.

fixed point math required for reproducibility. otherwise, the calculation could come out with a sligthly different value on the other side, and destabilize stacks. so all prediction math written in high precision fixed point math.

(gave up predicting rotation, smallest 3 linear instability, would not compress and reconstruct to the same values reliabily, if it doesn't decompress to same values, then it's not a good representation for doing a delta prediction).

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

(reader should understand the design constraints and what we are aiming at, and how the user can grab, throw, place and interact with cubes. would be good for the user to understand why making cubes non-physical why being held was a slam dunk, and some of the cool stuff like the recursive walk to transmit authority, having to detect support objects when you pull an object out from the bottom of a stack, so objects above it wake up, and so on..., also the calculations for throwing an object, including spin would be good to explain, plus the competing requirements for placing objects at a distance vs. throwing them and the zoom to hand and how that solves the movement problem in VR, eg. stops you punching through walls and your monitor in VR, eg. bring the world to you, vs. you going to the world).

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

(reader should understand that when we go above two players, we need to decide on a topology, client/server or peer-to-peer, and we need to decide between dedicated servers, player hosted server as well. pros and cons of each and why we went with client/server.)

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


---------

(kindof like a turn to part three here? not sure yet).

...

# 60HZ vs. 90HZ

(reader should understand concept of unity FixedUpdate vs. Update, interpolation of state for render, and why this is a good thing, but adds jitter)

# Real World Networking

(What to expect over the real world, eg. why is it so jittery! best effort delivery. no guarantee of nicely spaced packets etc. what this means for smoothness, eg. time shift of physics state and when its applied. also, the 60/90HZ render and physcis update separation is also a source of jitter in Unity).

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

(interpolation in remote view, simulation rewind and rollback, possibly a subset of simulation could be rolled back only, having basically the same properties as this authority scheme, but having server authoritative physics. gain: security, loss: in cases where players interact with the same stack, or both throw an object at a stack. dedicated servers for physics simulation, quantizing rotation to a different representation than smallest 3, eg. quantized 4, prediction of PhysX simulation including rotation)

# Conclusion

Sum up everything done, in order. Key points required to get it working.

(call to action: Link once again to demo. Try it out yourself.)

----- 

<i>
**Glenn Fiedler** is the founder and president of [The Network Protocol Company](http://thenetworkprotocolcompany.com) where he helps clients network their games. Prior to starting his own company he was a senior programmer at Respawn Entertainment working on Titanfall 1 and 2.

Glenn is also the author of several popular series of articles on game networking and physics at [gafferongames.com](http://www.gafferongames.com), and is the author of the open source network libraries [libyojimbo](http://www.libyojimbo.com) and [netcode.io](http://netcode.io)

If you would like to support Glenn's work, you can do that on [patreon.com](http://www.patreon.com/gafferongames)
</i>
