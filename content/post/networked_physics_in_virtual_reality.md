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

My goal for this project was to see if it was be possible to network a large number of physically simulated cubes that players can interact with in VR. Ideally players should have no latency when picking up, moving, placing and throwing cubes. The stretch goal: players should be able to construct stable stacks of cubes, stacks that network without any jitter or instability.

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

When it works, deterministic lockstep is an elegant technique, but it has limitations. The first is of course that the game must be deterministic, the second is that it's best used for small player counts like 2-4 players because you have to wait for input from the most lagged player, and third, if latency hiding is required, you need to make a full copy of the simulation and step it forward with local inputs, which can be very CPU intensive.

So will deterministic lockstep work for the our demo? Unfortunately the answer is _no_. The physics engine used by Unity is PhysX, and PhysX is not guaranteed to be deterministic.

# What about client-side prediction?

Another networking concept most people are familiar with is client-side prediction. This technique is used by first person shooters like Counterstrike, Call of Duty, Titanfall and Overwatch.

It works by treating the local player as separate from the rest of the world. The local player is predicted forward with local inputs, including movement, shooting, reloading and item usage, so the player feels no latency on their actions, while the rest of the world is synchronized back from the server to the client and rendered as an interpolation between keyframes.

They key benefit of client-side prediction is that the server remains authoritative over the simulation. To do this the server continuously sends corrections back to the client, in effect telling the client, at this time I think you were _here_ and doing _this_. But the client can't just apply those corrections as-is, because by the time they arrive they are _in the past_, so the client (invisibly) rolls the local player back in time, applies the correction and replays local inputs to bring the corrected player state back to present time.

These rollbacks happen all the time in first person shooters but you rarely notice, because your local player state and the corrected state almost always agree. When they don't, it's usually because you've experienced a patch of really bad network conditions and the server didn't receive all your inputs, or something happened on the server that can't be predicted from your inputs alone (another player shot you), or... because you were cheating :)

What's interesting is that client-side prediction doesn't require determinism. It doesn't hurt of course, but since the client and server exchange state as well as inputs, any non-determinism is quickly squashed by applying state to keep the simulations in sync. In effect, all client-side prediction requires is a _close enough_ extrapolation from a player state given the same inputs for approximately a quarter of a second.

So client side prediction works _great_ for first person shooters, but is it a good technique for networking a physics simulation?

In a first person shooter prediction is applied only to your local player character and perhaps objects you are carrying like items and weapons, but in a physics simulation what needs to be predicted to hide latency? Not only your own character, but any objects you interact with as well. This means if you pick up an object and throw it at a stack of objects, the client side prediction would need to include the set of objects you interact with, and in turn any objects they interact with, and so on.

While this could _theoretically_ work, it's easy to see that the worst case when a player throws a cube at a large stack of cubes is a client predicting the _entire simulation_. Under typical internet conditions it can be expected that players will need to predict up to 250ms to hide latency and at 60HZ this means a client-side prediction of 15 frames. Physics simulations are usually pretty expensive, so anything that requires 15 invisible rollback frames for each frame of real simulation is probably not practical.

# What could a solution look like?

At this point I think both techniques above can be ruled out:

1. PhysX is not deterministic, so we can't use deterministic lockstep.

2. Rolling back and resimulating the entire simulation is too expensive, so we can't hide latency with client-side prediction.

Any solution we come up would need to work with a physics engine that isn't deterministic, and provide some way to hide latency without client-side prediction.

# The Authority Scheme

The number one rule of networking is _never trust the client_. 

As with all good rules, this one is made to be broken. Never in a competitive game like an FPS, but in a _cooperative experience_, it's something to consider when there are no other options.

Which brings us to the concept of an authority scheme. The basic idea is that instead of having the server be authoritative over the whole simulation, we _distribute_ authority across player machines, such that players take authority over objects they interact with, in effect _becoming the server_ for those objects. If we do this correctly, from each player's point of view, players get to interact with objects lag free, and they never have to rollback and apply corrections. Also, because we are synchronizing state, determinism is not required.

The trick to making this all work is _clearly defined rules_ that keep the distributed simulation in sync while letting players predictively take authority over objects, resolving any conflicts between players after the fact.

To do this, I came up with two concepts:

1. Authority
2. Ownership

Authority is transmissive. Any object under the authority of a player transmits authority to objects it collides with, and those objects in turn transmit authority to objects they interact with. When objects come to rest, they return to default authority. Bonus points: if a stack is under authority of one player when another player throws an object at it, the more recently thrown object should take authority of the stack.

Ownership corresponds to a player grabbing an object and holding it in one of their avatar hands. Ownership is stronger than authority. Once a player owns an object (and the server confirms ownership) that player retains ownership until they release the object or disconnect from the game.

In both cases, players take authority and ownership without waiting for confirmation from the server. It's the server's job to keep the simulation consistent, which means correcting (but not rolling back and resimulating) any client who thinks they have taken authority or ownership, when another client beat them to it.

In short, we are creating a distributed system that is eventually consistent.

# State Synchronization

Trusting that I could implement the rules described above, my first task was to prove that synchronizing physics in one direction of flow could actually work with Unity and PhysX.

To do this I setup a simple loopback scene in Unity with 360 simulated cubes that fall from the sky into a large pile in front of the player. These cubes represent the authority side, and an identical set of cubes to the right act as the non-authority side they are synchronized to. The goal: to keep the simulation on the right in sync with the simulation in front of the player.

_(diagram showing synchronization from left to right)_

Testing network code in loopback like this is a best practice when developing AAA network code. It speeds up iteration time and makes debugging so much easier. In virtual reality it makes even more sense, considering the alternative, which is running the same virtual reality scene on two machines and switching headsets as you work :)

As expected, with nothing keeping the two sets of cubes in sync, even though they both start from exactly the same initial state and run through exactly the same simulation steps, they give different end results:

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

When we apply this state to the simulation on the right side, we force the position, rotation, linear and angular velocity of each rigid body to the state grabbed from the authority simulation. This simple change is enough to keep the simulations in sync, and PhysX doesn't diverge enough in the 1/10th of a second between updates to show any noticeable pops.

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

This is a straightforward optimization that saves bandwidth in the common case because at any time most objects are at rest. It's also a _lossless_ technique because it doesn't change the the state sent over the network in any way.

To optimize bandwidth further we need to use _lossy techniques_. This means we reduce the precision of the physics state when it's sent over the network. For example, we could bound position in some min/max range and quantize it to a precision of 1/1000th of a centimeter. We can use the same approach for linear and angular velocity, and for rotation we can use the _smallest three representation_ of a quaternion.

While this saves a bunch of bandwidth, the extrapolation on the non-authority side is now slightly different. What we want is an extrapolation that matches the authority side of the simulation as closely as possible. But how can we do this, and still use lossy compression? 

The solution is to quantize the state on _both sides_. What this means in practice is that before each physics simulation step, the physics state is sampled and quantized _exactly the same way_ as when it's sent over the network, then applied back to the local simulation. 

This is done on both the authority and non-authority sides. Now the extrapolation from quantized state on the non-authority side matches the authority side as closely as possible, because both simulations and network packets are quantized exactly the same way.

# Coming To Rest

But quantizing the state has some _very interesting_ side-effects...

1. PhysX doesn't really like you forcing the state of each rigid body at the start of every frame and it makes sure you know by taking up a bunch of CPU.

2. Quantization adds error to position which PhysX tries very hard to correct, snapping objects immediately out of penetration.

3. Rotations can't be represented exactly either, again causing penetration. Interestingly in this case, objects can get stuck in a feedback loop where they slide across the floor.

4. Although objects in large stacks _seem_ to be at rest, they are actually jittering by small amounts, visible only in the editor as tiny fluctuations as objects repeatedly try to resolve penetration due to quantization, or are quantized just above a resting surface and fall towards it.

While we can't do much about PhysX CPU usage, the solution for penetration is to set _maxDepenetrationVelocity_ on each rigid body, limiting the velocity that objects are pushed apart with.

Now to get objects to property come to rest, disable the PhysX at rest calculation and replace it with a ring-buffer of positions and orientations for each object. If an object has not moved or rotated significantly in the last 16 frames, force it to rest. Problem solved.

# Priority Accumulator

The next biggest optimization is to add the ability to send only a subset of objects per-packet. This gives us fine control over the amount of bandwidth we send, by setting a maximum packet size and sending only the set of state updates that fit in each packet.

How it works in practice:

1. Each object has a _priority factor_ which is calculated each frame. Higher values are more likely to be sent. Negative values mean _"don't send this object"_.

2. If the priority factor is positive, it's added to the _priority accumulator_ value for that object. This value persists between simulation updates such that the priority accumulator increases each frame, such that objects with higher priority rise faster than objects with low priority.

3. Negative priority factors clear the priority accumulator to -1.0.

4. When a packet is sent, the set of objects are sorted in order of highest priority accumulator to lowest. The first n objects are selected from the set to become the set of objects to potentially include in the packet. Objects with negative priority accumulator values are excluded from this set.

5. The packet is written and objects are serialized to the packet in order of importance. Not all state updates may fit in the packet, since object updates have a variable encoding depending on their current state (at rest vs. not at rest). Therefore the packet serialization returns to the caller a flag per-object indicating whether it was included in the packet.

6. Priority accumulator values for objects sent in the packet are cleared to 0.0, giving other objects fair a chance to be included in the next packet.

For this demo I found some value in boosting priority for cubes recently involved in high energy collisions, since high energy collision was the largest source of divergence due to non-deterministic results.

Somewhat counter-intuitively, I found that reducing priority for at rest objects gave bad results. My theory is that since the simulation runs on both sides, at rest objects would get nudged slightly out of sync and not be corrected quickly enough, leading to divergence when other cubes collide with them.

# Delta Compression

The next bandwidth reduction technique is _delta compression_.

First person shooters often implement this by compressing the entire state of the world relative to a previous state. In this technique, a previous world state or 'snapshot' acts as the _baseline_, and a set of differences, or _delta_, between the _baseline_ and _current_ snapshots are sent down to the client.

This technique is relatively easy to implement because all the server needs to do is track the most recent snapshot received by each client, and generate deltas from that snapshot to the current. Similarly, all the client needs to do is keep a buffer of the last n snapshots received, so it can reconstruct snapshots by applying deltas on top of its cached copy of the baseline.

When a priority accumulator is used delta encoding becomes more complicated.

Now the server (or authority-side) can't simply encode objects relative to a previous snapshot number, because not all objects are included in each packet. Instead,  the baseline must be specified _per-object_, so the receiver knows which state the object was encoded relative to.

The supporting systems and data structures are also much more complicated:

1. A reliability system is required that can report back to the sender which packets were received, not just the most recently received snapshot #.

2. The sender needs to track the states included in each packet sent, so it can map packet level acks to sent states and update the most recently acked state per-object.

3. The receiver needs to store a ring-buffer of received states per-object, so it can reconstruct the current object state from the delta.

But ultimately it's worth the extra complexity, because this system combines the flexibility of being able to specify a dynamic maximum packet size, and the bandwidth savings of delta compression, which is a potent combination.

# Delta Encoding

The simplest form of delta encoding is to send objects that haven't changed from the baseline value as just one bit: _not changed_. This is also the easiest gain you'll ever see, because most of the time, the majority of objects are at rest.

A more advanced strategy is to encode the _difference_ between the current and baseline values, aiming to encode small differences with fewer bits. For example, delta position could be (-1,+23,+4) from baseline. This works well for differences in linear values, but breaks down somewhat for deltas of the smallest three quaternion representation, as the largest component of a quaternion is often different between the baseline and current rotation.

Encoding the difference gives some gains, but it's not an order of magnitude win like not changed. This is because in many cases falling objects move quickly, so the difference in their values becomes large enough to negate most gains. This is especially true in the case where all objects falling from the sky into a big pile, which is arguably where we need bandwidth reductions the most.

The final strategy is that of predicting the future state and then encoding the error relative to it. This is complicated somewhat by the fact that the predictor must be written in fixed point, because floating point calculations are not necessarily guaranteed to be deterministic, especially between different platforms and hardware. But it's definitely achievable. In a few days of tweaking and experimentation, I was able to write an accurate predictor for position, linear and angular velocity that matched the future result to quantization resolution more than 90% of the time as objects fell. Encoding these objects was therefore easy, another bit _perfect prediction_.

When the prediction was less than perfect a small error offset encodes the difference between the values predicted from the baseline and their true values. In the case of collision, 


----------------------------

(reader should understand that we can send the linear difference between baseline position and current position as an offset, and the same for linear and angular velocity. reader should understand that we can encode this with the 0, -1, +1, -2, +2 mapping to make compression easier, but that compressing variable sized deltas is pretty inefficient with bitpacking, and would be better compressed with arithmetic or range encoding, but it's still a win, the trick is to use the least bits for the most statistically common differences).

(reader should also understand that orientation is not delta compressed. smallest 3 representation is a poor choice of rotation representation for delta encoding, because as an object rotates you can have a different set of smallest 3 components in the quaternion, hence they're not guaranteed to always be close to each other. a different representation of rotation would be better.)

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
**Glenn Fiedler** is the founder and president of [The Network Protocol Company](http://thenetworkprotocolcompany.com) where he helps clients network their games. Prior to starting his own company he worked at Respawn Entertainment on Titanfall 1 and 2.

Glenn is also the author of several popular series of articles on game networking and physics at [gafferongames.com](http://www.gafferongames.com), and is the author of the open source network libraries [libyojimbo](http://www.libyojimbo.com) and [netcode.io](http://netcode.io)

If you would like to support Glenn's work, you can do that on [patreon.com](http://www.patreon.com/gafferongames)
</i>
