+++
categories = ["Networked Physics"]
tags = ["physics","networking"]
date = "2014-11-28"
title = "Introduction to Networked Physics"
description = "Three ways to network a physics simulation"
draft = false
+++

## Introduction

Hi, I'm [Glenn Fiedler](https://gafferongames.com) and welcome to the first article in **[Networked Physics](/categories/networked-physics/)**.

In this article series we're going to network a physics simulation three different ways: deterministic lockstep, snapshot interpolation and state synchronization.

But before we get to this, let's spend some time exploring the physics simulation we’re going to network in this article series:

<video preload="auto" autoplay="autoplay" loop="loop" width="100%">
<source src="http://gafferongames.com/videos/the_physics_simulation_cube.mp4" type="video/mp4" />
<source src="http://gafferongames.com/videos/the_physics_simulation_cube.webm" type="video/webm" />
Your browser does not support the video tag.
</video>

Here I’ve setup a simple simulation of a cube in the open source physics engine [ODE](http://www.ode.org). The player moves around by applying forces at its center of mass. The physics simulation takes this linear motion and calculates friction as the cube collides with the ground, inducing a rolling and tumbling motion.

This is why I chose a cube instead a sphere. I _want_ this complex, unpredictable motion because rigid bodies in general move in interesting ways according to their shape.

## An Interactive World

Networked physics get interesting when the player interacts with other physically simulated objects, _especially_ when those objects push back and affect the motion of the player. 

So let's add some more cubes to the simulation:

<video preload="auto" autoplay="autoplay" loop="loop" width="100%">
<source src="http://gafferongames.com/videos/the_physics_simulation_cubes_roll.mp4" type="video/mp4" />
<source src="http://gafferongames.com/videos/the_physics_simulation_cubes_roll.webm" type="video/webm" />
Your browser does not support the video tag.
</video>

When the player interacts with a cube it turns red. When that cube comes to rest it turns back to grey (non-interacting).

While it’s cool to roll around and interact with other cubes, what I really wanted was a way to push _lots_ of cubes around. What I came up with is this:

<video preload="auto" autoplay="autoplay" loop="loop" width="100%">
<source src="http://gafferongames.com/videos/the_physics_simulation_cubes_blow.mp4" type="video/mp4" />
<source src="http://gafferongames.com/videos/the_physics_simulation_cubes_blow.webm" type="video/webm" />
Your browser does not support the video tag.
</video>

As you can see, interactions aren’t just direct. Red cubes pushed around by the player turn other cubes they touch red as well. This way, interactions fan out to cover all affected objects.

## A Complicated Case

I also wanted a very complex coupled motion between the player and non-player cubes such they become one system: a group of rigid bodies joined together by constraints. 

To implement this I thought it would be cool if the player could roll around and create a ball of cubes, like in one of my favorite games [Katamari Damacy](https://en.wikipedia.org/wiki/Katamari_Damacy).

<video preload="auto" autoplay="autoplay" loop="loop" width="100%">
<source src="http://gafferongames.com/videos/the_physics_simulation_cubes_katamari.mp4" type="video/mp4" />
<source src="http://gafferongames.com/videos/the_physics_simulation_cubes_katamari.webm" type="video/webm" />
Your browser does not support the video tag.
</video>

Cubes within a certain distance of the player have a force applied towards the center of the cube. These cubes remain physically simulated while in the katamari ball, they are not just “stuck” to the player like in the original game. 

This is a very difficult situation for networked physics!

__NEXT ARTICLE:__ [Deterministic Lockstep](/post/deterministic_lockstep/)

----- 

**Glenn Fiedler** is the founder and CEO of **[Network Next](https://networknext.com)**.<br><i>Network Next is fixing the internet for games by creating a marketplace for premium network transit.</i>
