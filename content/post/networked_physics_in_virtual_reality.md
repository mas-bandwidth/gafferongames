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

...

# The Problem

Latency.

Bandwidth.

Resolving conflicts.

...

# What about determinism?

Seemingly attractive. Low bandwidth. Send inputs only.

But PhysX is not guaranteed deterministic...

(Something about my discovery that the scene tends to play back the same way though, at least on my machine...)

...

# What about client-side prediction?

FPS games. Overview of how it works.

Why it's not a good idea here:

1. CPU bound. Non-starter with physics sim.

2. Rollback would potentially jarring in VR

...

# What could a solution look like?

(restriction to coop only)

Idea of distributing the world to hide. One player takes ownership of objects, se

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

# Delta Encoding

...

# Delta Prediction

...

# Interactivity

Grab, throw, stacking etc.

Rotate, zoom, snap to hand.

Concept of ownership vs. authority.

# Conflict Resolution

...

# Real World Networking

(What to expect over the real world, eg. why is it so jittery!)

...

# Smoothing

...

# Jitter Buffer

...

# Conclusion

...

----- 

<i>
**Glenn Fiedler** is the founder and president of [The Network Protocol Company](http://thenetworkprotocolcompany.com) where he helps clients network their games. Prior to starting his own company he was a senior programmer at Respawn Entertainment working on Titanfall 1 and 2.

Glenn is also the author of several popular series of articles on game networking and physics at [gafferongames.com](http://www.gafferongames.com), and is the author of the open source network libraries [libyojimbo](http://www.libyojimbo.com) and [netcode.io](http://netcode.io)

If you would like to support Glenn's work, you can do that on [patreon.com](http://www.patreon.com/gafferongames)
</i>
