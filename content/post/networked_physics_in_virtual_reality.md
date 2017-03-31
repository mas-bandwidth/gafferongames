+++
categories = ["White papers"]
tags = ["physics", "networking", "vr"]
date = "2017-03-31"
title = "Networked Physics in Virtual Reality"
description = "Networking a stack of cubes in virtual reality with Unity and PhysX"
draft = false
+++

# Introduction

Something about Oculus. Research etc.

...

# Background

Stable stacks. Describe the goal and why it's hard.

(Link ahead to try out the demo, read on to understand how it was implemented).

...

# The Problem

Latency.

Bandwidth.

Resolving conflicts.

...

# What about determinism?

Seemingly attractive. Low bandwidth. Send inputs only.

(Something about my discovery that the scene tends to play back the same way though, at least on my machine...)

But PhysX is not guaranteed deterministic...

When the creator of a physics library says it isn't guaranteed to be deterministic, listen to them.

...

# What about client-side prediction?

FPS games. Overview of how it works.

Why it's not a good idea here:

1. CPU bound. Non-starter with physics sim.

2. Rollback would potentially jarring in VR

...

# What could a solution look like?

(restriction to coop only)

Idea of distributing the world to hide. One player takes ownership of objects they interact with, sends state of those objects to other players.

...

# Authority scheme

...

# State Synchronization

<<Falling Stack of Cubes.>>

Flow in one direction.

Loopback scene. Blue -> red (mirror).

# Quantized State

...

# Coming to Rest

...

# Priority Accumulator

...

# Reliability

...

# Not Changed

...

# Delta Encoding

...

# Delta Prediction

...

# Interactivity

Grab, throw, stacking etc.

Rotate, zoom, snap to hand.

Concept of ownership vs. authority.

Thrown objects, hitting objects, stacking.

# Walking Interactions

(Recursive walk interacting objects, transmit authority).

(Return to color at rest for a period of time).

(Interesting notes, pulling objects from under stacks, requires manually waking objects above, manual walk for objects with height above threshold of object removed. Otherwise they hang there!)

...

# Client/Server

Introduce client/server topology and how it works. Not peer-to-peer.

(Necessary to buy into concept of host/guest, because host is arbiter of authority).

(Note that host could be a separate machine, eg. dedicated server, and in fact would be a lot cleaner in this case).

...

# Conflict Resolution

...

Boy this will be a complicated section. Might need to be broken down into sub-parts. Majority of the meat here.

...

# Real World Networking

(What to expect over the real world, eg. why is it so jittery!)

...

# Smoothing

...

# Jitter Buffer

...

# Conclusion

(Link to demo. Try it out yourself.)

...

----- 

<i>
**Glenn Fiedler** is the founder and president of [The Network Protocol Company](http://thenetworkprotocolcompany.com) where he helps clients network their games. Prior to starting his own company he was a senior programmer at Respawn Entertainment working on Titanfall 1 and 2.

Glenn is also the author of several popular series of articles on game networking and physics at [gafferongames.com](http://www.gafferongames.com), and is the author of the open source network libraries [libyojimbo](http://www.libyojimbo.com) and [netcode.io](http://netcode.io)

If you would like to support Glenn's work, you can do that on [patreon.com](http://www.patreon.com/gafferongames)
</i>
