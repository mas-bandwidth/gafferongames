+++
categories = ["Networked Physics"]
tags = ["physics","networking"]
date = "2014-11-28"
title = "The Physics Simulation"
description = "An introduction to networked physics"
draft = false
+++

## Introduction

Hi, I'm [Glenn Fiedler](/about) and welcome to the first article in **[Networked Physics](/categories/networked-physics/)**.

In this article series we're going to network a physics simulation three different ways: deterministic lockstep, snapshot interpolation and state synchronization.

But before we get to this, lets spend some time exploring the physics simulation we’re going to network.

<video preload="auto" autoplay="autoplay" loop="loop" width="100%">
<source src="http://new.gafferongames.com/videos/the_physics_simulation_cube.mp4" type="video/mp4" />
<source src="http://new.gafferongames.com/videos/the_physics_simulation_cube.webm" type="video/webm" />
Your browser does not support the video tag.
</video>

Here I’ve setup a simple simulation of a cube in the open source physics engine [ODE](http://www.ode.org). The player moves around by applying forces at its center of mass. The physics simulation takes this linear motion and calculates friction as the cube collides with the ground, inducing a rolling and tumbling motion.

This tumbling is why I chose a cube instead a sphere. I _want_ this complex, unpredictable motion because rigid bodies in general move in interesting ways according to their shape. It’s simply not possible to accurately predict the motion of a rigid body with a linear extrapolation or the ballistic equations of motion. 

If you want to know where a rigid body is at a future time, you have to run the whole physics simulation: dynamics, collision detection, collision response and friction in order to find out!

## An Interactive World

Networking a physics simulation is easy if there is only one object interacting with a static world. It starts to get interesting when the player interacts with other physically simulated objects, _especially_ when those objects push back and affect the motion of the player. 

Let's add some more cubes to the simulation:

<video preload="auto" autoplay="autoplay" loop="loop" width="100%">
<source src="http://new.gafferongames.com/videos/the_physics_simulation_cubes_roll.mp4" type="video/mp4" />
<source src="http://new.gafferongames.com/videos/the_physics_simulation_cubes_roll.webm" type="video/webm" />
Your browser does not support the video tag.
</video>

Notice when the player interacts with a cube it turns red. When that cube comes to rest it turns back to grey (non-interacting). Interactions aren’t just direct. Red cubes hit by the player turn other cubes they touch red as well. This way player interactions fan-out covering all affected objects.

While it’s cool to roll around and interact with other cubes, what I really wanted was a way to push _lots_ of cubes around. What I came up with is this:

<video preload="auto" autoplay="autoplay" loop="loop" width="100%">
<source src="http://new.gafferongames.com/videos/the_physics_simulation_cubes_blow.mp4" type="video/mp4" />
<source src="http://new.gafferongames.com/videos/the_physics_simulation_cubes_blow.webm" type="video/webm" />
Your browser does not support the video tag.
</video>

To implement this I raycast to find the intersection with the ground below the center of mass of the player cube, then apply a spring force (see [Hooke’s law](https://en.wikipedia.org/wiki/Hooke%27s_law)) relative to the distance from this point, making the player cube float in the air.

Then all non-player cubes within a certain distance of that intersection point have a force applied proportional to their distance from this point and away from it, so they are pushed away out of the way like leaves from a leaf blower.

## A Complicated Case

I also wanted a very complex coupled motion between the player and non-player cubes such that the player and the objects its interacting with become one single system, a group of rigid bodies joined together by constraints. 

To implement this I thought it would be cool if the player could roll around and create a ball of cubes, like in one of my favorite games [Katamari Damacy](https://en.wikipedia.org/wiki/Katamari_Damacy).

<video preload="auto" autoplay="autoplay" loop="loop" width="100%">
<source src="http://new.gafferongames.com/videos/the_physics_simulation_cubes_katamari.mp4" type="video/mp4" />
<source src="http://new.gafferongames.com/videos/the_physics_simulation_cubes_katamari.webm" type="video/webm" />
Your browser does not support the video tag.
</video>

To implement this effect cubes within a certain distance of the player have a force applied towards the center of the cube. These cubes remain physically simulated while in the katamari ball, they are not just “stuck” to the player like in the original game. 

This means that the cubes in the katamari are continually pushing and interacting with each other and the player cube via collision constraints. 

This is a very difficult situation for networked physics.
