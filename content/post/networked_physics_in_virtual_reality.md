+++
categories = ["White papers"]
tags = ["physics", "networking", "vr"]
date = "2017-03-31"
title = "Networked Physics in Virtual Reality"
description = "Networking a stack of cubes in virtual reality with Unity and PhysX"
draft = false
+++

# Introduction

Hi, I'm Glenn Fiedler, and for the last six months I've been researching networked physics in virtual reality.

This research was generously sponsored by [Oculus](https://www.oculus.com/), which turned out to be a great fit because the Oculus touch controller and Avatar SDK provide a fantastic way to _interact_ with a physics simulation in virtual reality.

My goal for this project was to see if it was be possible to network a large number of physically simulated cubes that players can interact with in VR. Ideally players should have no perceived latency when picking up, moving and placing cubes. The stretch goal: players should be able to construct stable stacks of cubes, stacks that network without any jitter or instability.

I'm happy to report this work was a success, and thanks to the generosity of Oculus, the full source code of my implementation in Unity is available [here](...). Please try this demo in virtual reality before continuing. While the rest of this article will explain how the demo was implemented, it's no substitute for actually getting in there in there and experiencing it.

# Background

Previously, I've [presented talks at GDC](http://www.gdcvault.com/play/1022195/Physics-for-Game-Programmers-Networking) about networked physics in the context of networking worlds of physically cubes, but it's entirely something different to be inside that world and be able to interact with it. This is something that at least to me, feels really exciting and new.

So when considering the best networking approach to use in virtual reality, it was clear that the key constraint that the player is actually _in there_. Objects being networked are literally _right in front of the player's face_. Any artifacts or glitches would be obvious and jarring, and any delay on the players actions would be unacceptable. Perhaps it would even make players feel sick?

My conclusion was that players _must_ be able interact with the world with absolutely no perception of latency. But achieving this with traditional networking techniques is difficult, so how can we do this?

# What about deterministic lockstep?

Deterministic lockstep is a technique where simulations are kept in sync by sending across just the inputs. It's attractive because the amount of bandwidth used is independent of the number of objects in the world.  

Most people know this technique from old school real-time strategy games like Command and Conquer, Age of Empires and StarCraft. It's a smart way to network these games because sending across the state for thousands of units is impractical.

Deterministic lockstep is also used in the networking of low player count fighting games like Street Fighter, and physics-based platformers like Little Big Planet. These games implement latency hiding techniques so the local player feels no lag on their own actions by predicting ahead a copy of the simulation with the local player's inputs.

What all these games have in common is that they're built on top of an engine that is _deterministic_. Determinism in this context means exactly the same result given the same inputs. Not near enough. Exact. Exact down to the bit-level so you could checksum the state at the end of each frame on all machines and it would be the same. In fact, deterministic lockstep games do this checksum all the time and disconnect any player who desyncs. 

When it works, deterministic lockstep is an elegant technique, but it has its limitations. The first is of course that the game must be deterministic, the second is that it's best used for small player counts like 2-4 players because you have to wait for input from the most lagged player, and third, if latency hiding is required, you need to make a full copy of the simulation and step it forward with local inputs, which can be very CPU intensive.

So will deterministic lockstep work for the our demo? Unfortunately the answer is _no_. The physics engine used by Unity is PhysX, and PhysX is not guaranteed to be deterministic.

# What about client-side prediction?

Another networking concept most people are familiar with is client-side prediction. This technique is used by first person shooters like Counterstrike, Call of Duty, Titanfall and Overwatch.

It works by treating the local player as separate from the rest of the world. The local player is predicted forward with local inputs, including movement, shooting, reloading and item usage, so the player feels no latency on their actions, while the rest of the world is synchronized back from the server to the client and rendered as an interpolation between keyframes.

They key benefit of client-side prediction is that the server remains authoritative over the simulation. To do this the server continuously sends corrections back to the client, in effect telling the client, at this time I think you were _here_ and doing _this_. But the client can't just apply those corrections as-is, because by the time they arrive they are _in the past_, so the client (invisibly) rolls the local player back in time, applies the correction and replays local inputs to bring the corrected player state back to present time.

These rollbacks happen all the time in first person shooters but you rarely notice, because your local player state and the corrected state almost always agree. When they don't, it's usually because you've experienced a patch of really bad network conditions and the server didn't receive all your inputs, or something happened on the server that can't be predicted from your inputs alone (another player shot you), or... because you were cheating :)

What's interesting is that client-side prediction doesn't require determinism. It doesn't hurt of course, but since the client and server exchange state instead of just inputs, any non-determinism is quickly squashed by applying state to keep the simulations in sync. In effect, all client-side prediction requires is a _close enough_ extrapolation from a player state given the same inputs for approximately a quarter of a second.

So client side prediction works _great_ for first person shooters, but is it a good technique for networking a physics simulation?

In a first person shooter prediction is applied only to your local player character and perhaps objects you are carrying like items and weapons, but in a physics simulation what needs to be predicted to hide latency? Not only your own character, but any objects you interact with as well. This means if you pick up an object and throw it at a stack of objects, the client side prediction would need to include the set of objects you interact with, and in turn any objects they interact with, and so on.

While this could _theoretically_ work, it's easy to see that the worst case for a player throwing a cube at a large stack of cubes is a client predicting the _entire simulation_. Under typical internet conditions it can be expected that players will need to predict up to 250ms to hide latency and at 60HZ this means a client-side prediction of 15 frames. Physics simulations are usually pretty expensive, so anything that requires 15 invisible rollback simulation frames for each frame of real simulation is probably not practical.

# What could a solution look like?

At this point I think both techniques above can be ruled out:

1. PhysX is not deterministic, so we can't use deterministic lockstep.

2. Rolling back and resimulating the entire simulation is too expensive, so we can't hide latency with client-side prediction.

Any solution we come up would need to work with a physics engine that isn't deterministic, and provide some way to hide latency without client-side prediction.

# The Authority Scheme

The number one rule of networking is _never trust the client_. 

As with all good rules, this one is made to be broken. Never in a competitive game like an FPS, but in a _cooperative experience_, it's something to consider when there are no other options.

Which brings us to the concept of an authority scheme. The basic idea is that instead of having the server be authoritative over the whole simulation, we _distribute_ authority across player machines, such that players take authority over objects they interact with, in effect _becoming the server_ for those objects. If we do this correctly, from each player's point of view, players get to interact with objects lag free, and they never have to rollback and apply corrections. Also, because we are synchronizing state, determinism is not required.

The trick to making this all work is to define _rules_ that keep the distributed simulation in sync while letting players predictively take authority over objects, resolving any conflicts after the fact.

To do this, I came up with two concepts:

1. Authority
2. Ownership

Authority is transmissive. Any object under the authority of a player transmits authority to other objects it collides with, and those objects in turn transmit authority to objects they interact with. When objects come to rest, they return to default authority. Bonus points: if a stack is under authority of one player when another player throws an object at it, the more recently thrown object should take authority of the stack.

Ownership corresponds to a player grabbing an object and holding it in one of their avatar hands. Ownership is stronger than authority. Once a player owns an object (and the server confirms ownership) that player retains ownership until they release the object or disconnect from the game.

In both cases, players take authority and ownership without waiting for confirmation from the server. It's the server's job to keep the simulation consistent, which means correcting (but not rolling back and resimulating) any client who thinks they have taken authority or ownership, when another client beat them to it.

In short, we are creating a distributed system that is eventually consistent.

# State Synchronization

Trusting that I could implement the rules described above, my first task was to prove that synchronizing physics in one direction of flow could actually work with Unity and PhysX.

To do this I setup a simple loopback scene in Unity with 360 simulated cubes that fell from the sky into a large pile in front of the player. These cubes represent the authority side, and an identical set of cubes to the right act as the non-authority side they would be synchronized to. The goal: to keep the simulation on the right in sync with the simulation in front of the player.

_(diagram showing synchronization from left to right)_

Testing network code in loopback like this is a best practice when developing AAA network code. It speeds up iteration time and makes debugging much easier. In virtual reality it makes even more sense, considering the alternative, which is running the same virtual reality scene on two machines and switching headsets as you work :)

As expected, with nothing keeping the two sets of cubes in sync, even though they both start from exactly the same initial state and run through the same simulation time steps, they give different end results:

_(screencap showing two scenes side-by-side in the editor, with different piles of objects)_

Not surprising because PhysX is non-deterministic. To fight this non-determinism, we'll grab state from the authority side and apply it to the non-authority side 10 times per-second. 

The state grabbed from each cube looks like this:

    struct CubeState
    {
        Vector3 position;
        Quaternion rotation;
        Vector3 linear_velocity;
        Vector3 angular_velocity;
    };

When we apply this state to the simulation on the right side, we apply it by _directly_ setting the position, rotation and velocities on each rigid body. This simple change is enough to keep the simulations in sync, and PhysX doesn't diverge enough in the 1/10th of a second between updates to show any noticeable pops.

Now the simulation on the right gives the same end result:

_(screen cap showing same resulting pile of cubes from top down in unity editor)_

This is actually a big step, because it proves that a _state synchronization_ based approach for networking can work with PhysX. The only problem is, sending uncompressed physics state uses too much bandwidth.

# Quantized State

A simple way to reduce bandwidth is to recognize when objects are at rest, and instead of sending (0,0,0) for linear velocity and angular velocity, we can just sent one bit "at rest":

    [position] (vector3)
    [rotation] (quaternion)
    [at rest] (bool)
    <if not at rest>
    {
        [linear_velocity] (vector3)
        [angular_velocity] (vector3)
    }

This is a straightforward optimization that saves a bunch of bandwidth in the common case. It's also _lossless_ because it doesn't change the the state sent over the network in any way.

To optimize further we need to use _lossy techniques_. These techniques reduce the precision of position, rotation and linear/angular velocity when they're sent over the network. 

For example, we could bound position in some min/max range, then quantize it such that its sent to some precision like 1/1000th of a centimeter. We can do the same for linear and angular velocity, and for orientation we can use the _smallest three_ representation of a quaternion.

This saves a bunch of bandwidth, but now extrapolation after we apply the network state on the non-authority side is slightly different because it's extrapolating from quantized state. This isn't good, because we want an extrapolation that matches the authority side of the simulation as closely as possible, so we can get stable stacks.

_(diagram showing a stack on left, with a quantized state on the right side with slight penetration_ -> jitter)_

The solution is to quantize the state on _both sides_. What this means is that before each physics simulation step is taken in **FixedUpdate**, the physics state is sampled, quantized _exactly_ is it would be sent over the network, then applied back to the local simulation.

Now the quantized state in the packet exactly matches the authority state, and the extrapolation is as close as possible.

# Quantum Side-Effects

Quantizing the state like this has side-effects. 

The first is that PhysX doesn't like it very much when you set the position, rotation and lin/ang velocity on each rigid body at the start of each frame (it takes a large amount of CPU). Perhaps PhysX could work to improve this, as it's a necessary part of networking physics statefully.

The second is that it adds some error to the simulation which PhysX tries very hard to correct for, throwing objects out of penetration with great force:

_(diagram showing cube in a stack in penetration due to position w. arrow)_

To fix this, make sure to set __(some function i forgot)__ on each rigid body, to limit the velocity that objects are pushed apart. I found that 1m/sec push apart works really well.

The third side-effect, which is quite subtle, is that some orientations can't be represented exactly in smallest three representation, leading to the following situation:

_(diagram showing cube rotating into penetration with the ground)_

What's interesting is that at certain orientations, the orientation after PhysX tries to pushes this cube out of penetration is another orientation that can't be exactly representated, leading to the comedic effect where the cube slides across the floor!

_(diagram showing cool sliding effect, three stage diagram, penetration, push out and to right, still in penetration_...)_

In my research I found that no amount of tuning or increasing the precision of rotation compression would fix this. If an edge of the cube rotated into penetration, it would induces sliding along the ground. 

From this I conclude that PhysX probably pushes objects out of penetration with a constant velocity, independent of the amount of penetration. Maybe if PhysX modified their solver so the amount of push out for small penetrations to be a function of penetration depth this would improve?


# Coming to Rest

I also noticed in large stacks that even though objects seemed to be at rest, they were actually jittering by small amounts, not visible in VR

Regardless, it has to work so ...

...



(reader should understand that quantizing the simulation at the start of each frame creates error, and this error results in objects going into slight penetration with the ground and other objects while they are in stacks, this causes jitter and destabilizes stacks, and breaks the regular PhysX at rest calculation, we have to write our own replacement that works with the limits of our quantization, reader should understand how this works with a ring buffer, and is focused on actual motion, so it ignores small imperceptible jitter in position/rotation, and only case if the objcet is moving sigificantly over time across a number of frames. physcis at rest heisenberg principle).

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

# Throwing

Might be cool to discuss the final pass changes to throwing necessary to get it feeling good.

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
