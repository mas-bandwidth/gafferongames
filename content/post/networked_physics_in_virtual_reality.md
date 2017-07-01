+++
categories = ["Networked Physics"]
tags = ["physics", "networking", "vr"]
date = "2017-03-31"
title = "Networked Physics in Virtual Reality"
description = "Networking a stack of cubes with Unity and PhysX"
draft = true
+++

# Introduction

Hi, I'm Glenn Fiedler, and for the last few months I've been researching networked physics in virtual reality. This research was generously sponsored by [Oculus](https://www.oculus.com/), which turned out to be a great fit because the Oculus touch controller and Avatar SDK provide a fantastic way to _interact_ with a physics simulation in virtual reality.

[<img src="/img/networked-physics-in-vr/touch.png" width="100%"/>](http://www.oculus.com)

My goal for this project was to network a world of physically simulated cubes in virtual reality, such that players would feel no latency when picking up, moving, placing and throwing cubes. My stretch goal: players should be able to construct stable stacks of cubes, stacks that network without any jitter or instability.

<img src="/img/networked-physics-in-vr/stack-of-cubes.jpg" width="100%"/>

I'm happy to report this work was a success, and thanks to the generosity of Oculus, the full source code of my implementation in Unity is available [here](...). 

Please try this demo in virtual reality before continuing. While the rest of this whitepaper explains how it was implemented, like most things in VR, it's no substitute for actually getting in there in there and experiencing it.

# Background

Previously, I've [presented talks at GDC](http://www.gdcvault.com/play/1022195/Physics-for-Game-Programmers-Networking) about networked physics. And yes, I've even networked worlds of physicaly simulated cubes before. But it's something completely different to be _inside_ that world and interact with it. This is something that at least to me, feels really exciting and new.

So when considering the best approach for networked physics in virtual reality, this seemed the most important factor. That the player is actually _in there_. Networked objects are right in front of the player's face. Any artifacts or glitches would be obvious and jarring, and any delay on a player's actions would be unacceptable. Perhaps it would even make players feel sick?

It seems obvious then that for any networking approach to work in virtual reality, it must allow players to interact with the world without any perception of latency. This makes a lot of sense considering how much effort has gone into VR platforms to reduce latency for tracking and player input. It would be a real shame to build something on top of this that adds latency due to networking.

So let's start by focusing on this aspect: _latency hiding_. How are multiplayer games networked and how do they hide latency? Can we use these techniques to network a physics simulation in VR with Unity and PhysX?

# Deterministic Lockstep

Deterministic lockstep is a technique where multiple simulations are kept in sync by sending across just the inputs. It's attractive because the amount of bandwidth used is independent of the number of objects in the world.  

<img src="/img/networked-physics-in-vr/starcraft2.jpg" width="100%"/>

Most people know this technique from old school real-time strategy games like **Command and Conquer**, **Age of Empires** and **StarCraft**. It's a smart way to network these games because sending across the state for thousands of units is impractical.

<img src="/img/networked-physics-in-vr/streetfighter.jpg" width="100%"/>

It's also used in the networking of fighting games like **Street Fighter**, and physics-based platformers like **Little Big Planet**. These games implement latency hiding techniques so the local player feels no lag on their own actions by predicting ahead a copy of the simulation with the local player's inputs.

<img src="/img/networked-physics-in-vr/littlebigplanet.jpg" width="100%"/>

What all these games have in common is that they're built on top of an engine that is _deterministic_. This means it gives exactly the same result given the same inputs. Exact down to the bit-level so you could checksum the game state at the end of each frame and it would the same across all player's machines.

So will deterministic lockstep work for the networked physics demo? Unfortunately the answer is _no_. The physics engine used by Unity is PhysX, and PhysX is not guaranteed to be deterministic.

# Client-Side Prediction

Another networking concept many people are familiar with is client-side prediction. This technique is used by first person shooters like **Counterstrike**, **Call of Duty**, **Titanfall** and **Overwatch**.

<img src="/img/networked-physics-in-vr/counterstrike.jpg" width="100%"/>

Client side prediction works by predicting the local player on each client forward with local inputs. This lets players move and shoot without feeling any latency in their own actions, while the rest of the world is synchronized from server to client and rendered as an interpolation between keyframes.

<img src="/img/networked-physics-in-vr/overwatch.jpg" width="100%"/>

The key benefit of client-side prediction is that the client feels no latency while the server remains authoritative over the simulation. This is achieved by continuously sending corrections from the server to the client, in effect telling the client, at this time I think you were _here_ and doing _this_.

Here's where it gets complicated. The client can't just apply the server corrections as-is, because by the time they arrive they're _in the past_, so the client (invisibly) rolls the local player back in time, applies the correction from the server, then replays local inputs to bring the corrected player state back up to present time on the client.

This happens all the time in first person shooters but you rarely notice, because the local player state and the corrected state almost always agree. When they don't, it's usually because something happened on the server that can't be predicted from your inputs alone (another player shot you), or... because you were cheating :)

<img src="/img/networked-physics-in-vr/titanfall.jpg" width="100%"/>

Client side prediction works _great_ for first person shooters, hiding latency while keeping the game secure against cheaters. But is it a good technique for networking a physics simulation?

<img src="/img/networked-physics-in-vr/callofduty.png" width="100%"/>

Unfortunately the answer is no. Why?

First person shooters apply prediction to your local player character, objects you are carrying like items and weapons, and depending on the game, projectiles like grenades and missiles. This works well because only a small subset of objects need to be rolled back and resimulated on each client.

But what if you wanted to throw an object at a stack of objects, and have the stack react without latency? What would need to be predicted and rolled back in this case? The answer is not only the object you throw, but also any objects it collides with, plus any objects they collide with and so on! 

While this could _theoretically_ work, the worst case is a client predicting the _entire simulation_ when all objects are in a big stack. This quickly becomes impractical because physics simulation is expensive. We simply can't afford to rollback and resimulate 10-15 frames of simulation just to hide latency.

# Distributed Simulation

The third technique is distributed simulation. The basic idea is that instead of having the server be authoritative over the whole simulation, authority is _distributed_ across player machines, such that players take authority over different parts of the world, in effect _becoming the server_ for those objects.

<img src="/img/networked-physics-in-vr/gta5.jpg" width="100%"/>

Distributed simulation is used in open world games like **Grand Theft Auto** because it distributes the cost of simulating a large world across player's machines. Latency is hidden by giving players authority over their own character and vehicles they are driving.

<img src="/img/networked-physics-in-vr/destiny.jpg" width="100%"/>

**Destiny** also uses a distributed simulation technique, distributing the cost of player and AI simulation across player machines, while keeping important aspects of mission scripting running on [lightweight dedicated servers](http://www.gdcvault.com/play/1022247/Shared-World-Shooter-Destiny-s). This significantly reduces server costs and makes it possible for Destiny to present the illusion of a seamless world.

<img src="/img/networked-physics-in-vr/darksouls.jpg" width="100%"/>

**Dark Souls** has no dedicated gameplay servers but allows players to invade other player's games. In this case, the invading player has authority over their own character, allowing them to move and attack without latency, while the host player has authority over the rest of the world.

<img src="/img/networked-physics-in-vr/thedivision.jpg" width="100%"/>

**The Division** also uses a distributed simulation approach. Each player runs the simulation for their player character locally, sending their position and actions to a dedicated server. This hides latency for the local player, while allowing the game to scale up to high player counts. However, this approach is not without controversy, as it has caused [serious cheating problems](https://www.theguardian.com/technology/2016/apr/26/hackers-cheats-ruined-the-division-pc-ubisoft) on PC.

# The Authority Scheme

(segway, conclusion, we're going to use distributed authority).

The host can takes authority over objects they interact with, turning the stack blue. 

<img src="/img/networked-physics-in-vr/temp.jpg" width="100%"/>

The host broadcasts state for all cubes to guests at some rate, like 10 times per-second:

<img src="/img/networked-physics-in-vr/quad.jpg" width="100%"/>

When objects come to rest, the return to default authority (white):

<img src="/img/networked-physics-in-vr/temp.jpg" width="100%"/>

Guests can also take authority over objects, for example player 1 turns cubes red:

<img src="/img/networked-physics-in-vr/temp2.jpg" width="100%"/>

While cubes are red, the player 1 ignores updates from the server for these objects and sends their state to the host:

<img src="/img/networked-physics-in-vr/quad2.jpg" width="100%"/>

The host accepts these state updates, applies them to its own simulation, and broadcasts them back out to all guests:

<img src="/img/networked-physics-in-vr/quad2.jpg" width="100%"/>

(Something something conclusion, what about conflicts? We will cover conflict resolution later, but in short, what we are doing is creating a distributed system that is eventually consistent).

# State Synchronization

Trusting that I could implement the rules described above, my first task was to prove that synchronizing physics in one direction of flow could actually work with Unity and PhysX.

To do this I setup a simple loopback scene in Unity where physically simulated cubes fall from the sky into a pile in front of the player. These cubes represent the authority side, and an identical set of cubes on the right act as the non-authority side.

<img src="/img/networked-physics-in-vr/authority-and-non-authority-cubes.png" width="100%"/>

As expected, with nothing keeping the two sets of cubes in sync, even though they both start from exactly the same initial state and run through exactly the same simulation steps, they give different end results:

<img src="/img/networked-physics-in-vr/out-of-sync.png" width="100%"/>

This is not exactly surprising because PhysX is non-deterministic. To fight this non-determinism, we'll grab state from the authority side and apply it to the non-authority side 10 times per-second. 

<img src="/img/networked-physics-in-vr/left-to-right.png" width="100%"/>

The state grabbed from each cube looks like this:

    struct CubeState
    {
        Vector3 position;
        Quaternion rotation;
        Vector3 linear_velocity;
        Vector3 angular_velocity;
    };

When we apply this state to the simulation on the right side, we force the position, rotation, linear and angular velocity of each rigid body to the state grabbed from the authority simulation. 

This simple change is enough to keep the simulations in sync, and PhysX doesn't diverge enough in the 1/10th of a second between updates to show any noticeable pops:

<img src="/img/networked-physics-in-vr/in-sync.png" width="100%"/>

This is actually a big step, because it proves that a _state synchronization_ based approach for networking can work with PhysX. The only problem is, sending uncompressed physics state uses too much bandwidth.

# Bandwidth Optimization

The first step towards reduce bandwidth is to recognize when objects are at rest, and instead of sending (0,0,0) for linear and angular velocity, send just one bit: "at rest".

    [position] (vector3)
    [rotation] (quaternion)
    [at rest] (bool)
    <if not at rest>
    {
        [linear_velocity] (vector3)
        [angular_velocity] (vector3)
    }

This is a straightforward optimization that saves bandwidth in the common case because at any time most objects are at rest. It's also a _lossless_ technique because it doesn't change the state sent over the network in any way.

To optimize bandwidth further we need to use _lossy techniques_. This means we reduce the precision of the physics state when it's sent over the network. For example, we could bound position in some min/max range and quantize it to a precision of 1/1000th of a centimeter. We can use the same approach for linear and angular velocity, and for rotation we can use the _smallest three representation_ of a quaternion.

While this saves a bunch of bandwidth, the extrapolation on the non-authority side is now slightly different. What we want is an extrapolation that matches the authority side of the simulation as closely as possible. But how can we do this, and still use lossy compression? 

The solution is to quantize the state on _both sides_. What this means in practice is that before each physics simulation step, the physics state is sampled and quantized _exactly the same way_ as when it's sent over the network, then applied back to the local simulation. 

This is done on both the authority and non-authority sides. Now the extrapolation from quantized state on the non-authority side matches the authority side as closely as possible, because both simulations and network packets are quantized exactly the same way.

# Coming To Rest

But quantizing the state has some _very interesting_ side-effects...

1. PhysX doesn't really like you forcing the state of each rigid body at the start of every frame and lets you know by taking up a bunch of CPU.

2. Quantization adds error to position which PhysX tries very hard to correct, snapping objects immediately out of penetration.

3. Rotations can't be represented exactly either, again causing penetration. Interestingly in this case, objects can get stuck in a feedback loop where they slide across the floor.

4. Although objects in large stacks _seem_ to be at rest, they are actually jittering by small amounts, visible only in the editor as tiny fluctuations in state values as objects repeatedly try to resolve penetration due to quantization, or are quantized just above a resting surface and fall towards it.

While we can't do much about PhysX CPU usage, the solution for penetration is to set _maxDepenetrationVelocity_ on each rigid body, limiting the velocity that objects are pushed apart with. 1 meter per-second seems to work well.

To get objects to come to rest, disable the PhysX at rest calculation and replace it with a ring-buffer of positions and rotations for each object. If an object has not moved or rotated significantly in the last 16 frames, force it to rest.

# Priority Accumulator

The next big optimization is to add the ability to send only a subset of objects per-packet. This gives us fine control over the amount of bandwidth we send, by setting a maximum packet size and sending only the set of updates that fit in each packet.

Here's how it works in practice:

1. Each object has a _priority factor_ which is calculated each frame. Higher values are more likely to be sent. Negative values mean _"don't send this object"_.

2. If the priority factor is positive, it's added to the _priority accumulator_ value for that object. This value persists between simulation updates such that the priority accumulator increases each frame, so objects with higher priority rise faster than objects with low priority.

3. Negative priority factors clear the priority accumulator to -1.0.

4. When a packet is sent, objects are sorted in order of highest priority accumulator to lowest. The first n objects are and become the set of objects to potentially include in the packet. Objects with negative priority accumulator values are excluded.

5. The packet is written and objects are serialized to the packet in order of importance. Not all state updates may fit in the packet, since object updates have a variable encoding depending on their current state (at rest vs. not at rest). Therefore, packet serialization returns a flag per-object indicating whether it was included.

6. Priority accumulator values for objects sent in the packet are cleared to 0.0, giving other objects a fair chance to be included in the next packet.

For this demo I found some value in boosting priority for cubes recently involved in high energy collisions, since high energy collision was the largest source of divergence due to non-deterministic results. I also boosting priority for cubes recently thrown by players.

Somewhat counter-intuitively, reducing priority for at rest objects gave bad results. My theory is that since the simulation runs on both sides, at rest objects would get nudged slightly out of sync and not be corrected quickly enough, causing divergence when other cubes collide with them.

# Delta Compression

And now, the king of bandwidth optimization: _delta compression_.

First person shooters often implement this by compressing the entire state of the world relative to a previous state. In this technique, a previous world state or 'snapshot' acts as the _baseline_, and a set of differences, or _delta_, between the _baseline_ and _current_ snapshots is generated and sent down to the client.

This technique is relatively easy to implement because all the server needs to do is track the most recent snapshot received by each client, and generate deltas from that snapshot to the current. Similarly, all the client needs to do is keep a buffer of the last n snapshots received, so it can reconstruct snapshots by applying deltas on top of its copy of the baseline.

When a priority accumulator is used delta encoding becomes more complicated.

Now the server (or authority-side) can't simply encode objects relative to a previous snapshot number, because not all objects are included in each packet. Instead, the baseline must be specified _per-object_, so the receiver knows which state each object is encoded relative to.

The supporting systems and data structures are also much more complicated:

1. A reliability system is required that can report back to the sender which packets were received, not just the most recently received snapshot #.

2. The sender needs to track the states included in each packet sent, so it can map packet level acks to sent states and update the most recently acked state per-object.

3. The receiver needs to store a ring-buffer of received states per-object, so it can reconstruct the current object state from the delta.

But ultimately it's worth the extra complexity, because this system combines the flexibility of being able to dynamically adjust bandwidth usage, with the orders of magnitude bandwidth improvements you get from delta encoding.

# Delta Encoding

But how do we actually encode the delta between object states?

The simplest way is to encode objects that haven't changed from the baseline value as just one bit: _not changed_. This is also the easiest gain you'll ever see, because at any time most objects are at rest.

A more advanced strategy is to encode the _difference_ between the current and baseline values, aiming to encode small differences with fewer bits. For example, delta position could be (-1,+23,+4) from baseline. This works well for linear values, but breaks down somewhat for deltas of the smallest three quaternion representation, as the largest component of a quaternion is often different between the baseline and current rotation.

So while encoding the difference gives some gains, it's not an order of magnitude improvement like _not changed_. This is because in many cases objects move quickly, so the difference in their values becomes large enough to negate most gains. This is especially true in the case where objects are falling from the sky, which is arguably where bandwidth reductions are needed the most.

The most advanced strategy is to use prediction. In this approach, the current state is predicted from the baseline state assuming the object is moving ballistically under acceleration due to gravity. This is complicated somewhat by the fact that the predictor must be written in fixed point, because floating point calculations are not necessarily guaranteed to be deterministic, but it's definitely achievable.

In a few days of tweaking and experimentation, I was able to write a ballistic predictor for position, linear and angular velocity that matched the PhysX integrator within quantize resolution about 90% of the time. These lucky objects are encoded with another bit: _perfect prediction_. Another order of magnitude improvement. For cases where the prediction doesn't match exactly, a small error offset is sent.

In the time I had to spend, I not able to get a good predictor for rotation. I blame this on the smallest three representation, which is numerically unstable, especially in fixed point. In the future, I would not use the smallest three representation for quantized rotations.

It was also painfully obvious while encoding differences and error offsets that a bitpacker was not the best way to read and write these quantities. Something like a range coder or arithmetic compressor that can represent fractional bits, and dynamically adjust to the average size of differences in the scene would give much better results.

# Synchronizing Avatars

Now that bandwidth is under control, how can we synchronize avatars?

Avatars are represented by a head and two hands driven by the tracked headset and touch controllers. We capture the position and rotations of the avatar components in _FixedUpdate_ along the rest of the physics state, but avatar state is actually sampled from the hardware at render framerate in _Update_.

This causes jitter when the avatar state is applied on the other side, because the sample time doesn't line up with _FixedUpdate_ on that machine. To fix this, we store the difference between physics and render time when we sample avatar state, so we can reconstruct the time of the avatar sample on the other side. 

Next, a jitter buffer with 100ms delay is applied to received packets, solving network jitter from time variance in packet delivery and enabling interpolation between avatar states. Physics state is applied to the simulation in _FixedUpdate_, while avatar state is applied at render time in _Update_ by interpolating between the two nearest samples in the jitter buffer.

While a cube is parented to an avatar hand, its _priority factor_ is set to -1, stopping it from being sent with regular physics state updates. Instead, its cube id and relative position and rotation are sent as part of the avatar state. Cubes are attached to the avatar hands in the remote view when the first avatar state arrives with that cube parented to a hand, and detached when regular physics state updates resume, corresponding to the cube being thrown or released.

# Bidirectional Flow

Now lets add another player on the right:

_(diagram showing loopback scene with player on right)_

We'll call the this player the _guest_, and the original player the _host_.

The guest takes authority and ownership of objects without waiting for acknowledgement from the host, which allows the guest to interact with the simulation with no latency. 

Of course the host needs to see what the guest does, so the guest sends state for cubes it interacts with (has authority over) back to the host, plus the state for its avatar, which implicitly includes state for cubes held by the guest.

_(diagram showing flow from guest -> host)_

The host and guest both check the local state of cubes before taking authority and ownership. For example, the host won't take authority over an object already under authority of the guest and vice-versa, and players can't grab cubes already held by another player.

Despite this, it's possible for two players to predictively take authority or ownership over the same object under latency, when each player acquires the object before seeing the other player's action. Because of this, we need a way to resolve conflicts after the fact.

# Resolving Conflicts

Now consider the case of a host and three guests:

_(diagram showing host and three guests in client/server topology)_

As you can see, this is a client/server topology rather than peer-to-peer. In this topology, all packets flow through the host, making the host the _arbiter_. In other words, the host decides which state updates to accept, and which to ignore and subsequently correct.

To apply these corrections we need some way for the host to override guests and say, no, you don't have authority or ownership over this object, and you should accept this update. We also need some way for the host to determine _ordering_ for guest interactions with the world, so if one client experiences a burst of lag and delivers a bunch of packets late, these packets won't take precedence over more recent actions from other guests.

This is achieved with two sequence numbers:

1. Authority sequence

2. Ownership sequence

These sequence numbers are sent along with each state update and included in avatar state when cubes are held by players. They are used by the host to determine if it should accept an update from guests, and by guests to determine if the state update from the server is more recent and should be accepted, even when that guest thinks it has authority or ownership over an object.

Authority sequence increments each time a player takes authority over an object and when an object under authority of a player comes to rest. When an object has authority on a guest machine, it holds authority on that machine until it receives _confirmation_ from the host before returning to default authority. This ensures that the final at rest state for objects under guest authority are committed back to the host, even under significant packet loss.

Ownership sequence increments each time a player grabs an object. Ownership is stronger that authority, such that an increase in ownership sequence wins over an increase in authority sequence number. For example, if a player interacts with an object just before another player grabs it, the player who grabbed it wins.

These rules are sufficient to resolve conflicts, while letting host and guest players can interact with the world lag free. Corrections are rare in practice, and when they do occur, the simulation quickly converges to a consistent state.

# Conclusion

High quality networked physics with stable stacks of objects is possible with Unity and PhysX using an authority-based network model. This approach is best used for _cooperative experiences only_, as it does not provide the security of a server-authoritative network model.

----- 

<i>
**Glenn Fiedler** is the founder and president of [The Network Protocol Company](http://thenetworkprotocolcompany.com) where he helps clients network their games. Prior to starting his own company he worked at Respawn Entertainment on Titanfall 1 and 2.

Glenn is also the author of several popular series of articles on game networking and physics at [gafferongames.com](http://www.gafferongames.com), and is the author of the open source network libraries [libyojimbo](http://www.libyojimbo.com) and [netcode.io](http://netcode.io)

If you would like to support Glenn's work, you can do that on [patreon.com](http://www.patreon.com/gafferongames)
</i>
