+++
categories = ["Game Physics"]
tags = ["physics"]
date = "2005-06-01"
title = "Integration Basics"
description = "How to integrate the equations of motion"
draft = false
+++

## Introduction

Hi, I'm [Glenn Fiedler](/about) and welcome to the first article in **[Game Physics](/categories/game-physics/)**.

If you have ever wondered how the physics simulation in a computer game works then this series of articles will explain it for you. I assume you are proficient with C++ and have a basic grasp of physics and mathematics. Nothing else will be required if you pay attention and study the example source code.

A physics simulation works by making many small predictions based on the laws of physics. These predictions are actually quite simple, and basically boil down to something like "that the object is here, and is traveling this fast in that direction, so in a short amount of time it should be over there". We perform these predictions using a mathematical technique called integration.

Exactly how to implement this integration is the subject of this article.

## Integrating the Equations of Motion

You may remember from high school or university physics that force equals mass times acceleration. 

        f = ma

We can switch this around to see that acceleration is force divided by mass. This makes intuitive sense because the more an object weighs, the less acceleration it receives from the same amount of force. Heavier objects are harder to throw.

        a = f/m

Since acceleration is the rate of change in velocity over time, we can say that force divided by mass is the rate of change in velocity:

        dv/dt = a = F/m

Similarly, velocity is the rate of change in position over time:

        dx/dt = v

This means that if we know the current position and velocity of an object, and the forces that will be applied to it, we can integrate to find its position and velocity at some time in the future.

## Numerical Integration

For those who have not formally studied differential equations at university, take heart for you are in just as good a position as those who have! This is because we are not going to solve the differential equations as you would normally do in first year mathematics, instead we are going to **numerically integrate** to find the solution.

Here's how numerical integration works. First, start at an initial position and velocity, then take a small step forward to find the velocity and position at a future time. Then, repeat this, moving forward in time in small discrete steps, using the result of the previous step as the starting point for the next.

But how do we find the amount of change in velocity and position each step? 

The answer lies in the **equations of motion**. 

Lets call our current time **t** and the time step **dt** or 'delta time'.

Now we can put the equations of motion in a form anyone can understand:

        acceleration = force / mass
        
        change in velocity = acceleration * dt
        
        change in position = velocity * dt

This makes intuitive sense because we know if we're traveling 60 kilometers per-hour in a car, then in one hour we’ll be exactly 60 kilometers further down the road. Similarly, if a car accelerates at 10 kilometers per-hour per-second from a standing start, in 10 seconds it will be travelling at 100 kilometers per hour.

Of course this logic lonly holds when acceleration and velocity are constant. But even when they're not, it's still a decent approximation to start with.

Lets put this into code. Starting with a stationary object at the origin weighing one kilogram we apply a constant force of 10 newtons per-second and step forward one second at a time:

        double t = 0.0;
        float dt = 1.0f;

        float velocity = 0.0f;
        float position = 0.0f;
        float force = 10.0f;
        float mass = 1.0f;

        while ( t <= 10.0f )
        {
            position = position + velocity * dt;
            velocity = velocity + ( force / mass ) * dt;
            t += dt;
        }

Here is the result:

        t=0:    position = 0      velocity = 0
        t=1:    position = 0      velocity = 10
        t=2:    position = 10     velocity = 20
        t=3:    position = 30     velocity = 30
        t=4:    position = 60     velocity = 40
        t=5:    position = 100    velocity = 50
        t=6:    position = 150    velocity = 60
        t=7:    position = 210    velocity = 70
        t=8:    position = 280    velocity = 80
        t=9:    position = 360    velocity = 90
        t=10:   position = 450    velocity = 100

As you can see, at at each step we know both the position and velocity of the object. This is numerical integration.

## Why Euler Integration is not (always) so great

What we just did is called Euler Integration. Specifically it is a type of euler integration called **explicit euler**.

To save you future embarrassment, I must point out now that Euler is pronounced "Oiler" not "yew-ler" as it is the last name of the Swiss mathematician [Leonhard Euler](https://en.wikipedia.org/wiki/Leonhard_Euler) who first discovered this technique.

Euler integration is the most basic of numerical integration techniques. It is only 100% accurate when the rate of change is constant over the timestep.

Since acceleration is constant in the example above, the integration of velocity is without error. However, we are also integrating velocity to get the position each step, and velocity is increasing 10 meters per-second per-second due to acceleration, so velocity is definitely _not_ constant. This means there is error in the integrated position.

Just how large is this error? Lets find out!

There is a closed form solution for how an object moves under constant acceleration. We can use this equation to compare our numerically integrated result against the exact result:

        s = ut + 0.5at^2
        s = 0.0*t + 0.5at^2
        s = 0.5(10)(10^2)
        s = 0.5(10)(100)
        s = 500 meters

After 10 seconds, the object should have moved 500 meters, but explicit euler integration with one second time steps gives a result of 450 meters. That's 50 meters off after just 10 seconds! 

This sounds really, really bad, but it's not common for games to step physics forward with such large time steps. In fact, physics usually steps forward at something closer to the display framerate. Otherwise, how would the physics simulation react to player input?

If we step forward with **dt** = 1/100, the result is much closer to the exact value:

        t=10:   position = 450    velocity = 100
        t=10:   position = 450    velocity = 100
        t=10:   position = 450    velocity = 100
        t=10:   position = 450    velocity = 100
        t=10:   position = 450    velocity = 100
        t=10:   position = 450    velocity = 100
        t=10:   position = 450    velocity = 100
        t=10:   position = 450    velocity = 100
        t=10:   position = 450    velocity = 100
        t=10:   position = 450    velocity = 100

(rewrite paragraph below, it's too ominous. error exists, but it's not the end of the world for most game simulations)

However, no matter how much you reduce your timestep, the simple truth is that the error will always be there and that it will keep increasing over time. Given that this is an extremely simple simulation, imagine something as simple as adding a torque curve to the car, or adding gears. Suddenly the car’s acceleration is not a constant, it changes over time. Now there is error when integrating the velocity, and these errors are magnified even further when integrating the position.

## Many different integration methods exist

You can see that explicit euler has a large amount of error in the case above, but it’s a gross simplification to say that it is terrible or that it should never be used. Just be aware of its shortcomings. There are also several other Euler method variants with different properties to consider.

For example, semi-implicit euler (symplectic euler) is a method that changes the point of time where velocity is sampled. It adds acceleration to velocity first, and then updates position from that updated velocity vs. the other way around. This small change gives the integrator different properties and it is more stable and energy conserving across a wider range of time steps.

        while ( t <= 10.0f )
        {
            position = position + velocity * dt;
            velocity = velocity + ( force / mass ) * dt;
            t = t + dt;
        }

A completely different option is implicit or [backwards euler](http://web.mit.edu/10.001/Web/Course_Notes/Differential_Equations_Notes/node3.html). This method is better for simulating stiff equations (eg. stiff springs) that break down and become unstable with other methods. It's much more involved and requires solving a system of equations per-timestep vs. just adding velocity * dt to position and so on.

Another excellent option for greater accuracy and less memory when simulating a large number of particles is [verlet integration](https://en.wikipedia.org/wiki/Verlet_integration). In this case, the integrator does not require storing velocity per-particle, as it derives it from the difference in the previous two frames position values. This makes collision detection and position fix-up (eg. pushing particles out of collision) really quick and easy to implement.

In this article I’m going to introduce the "RK4" integrator, eg. Runge Kutta order 4, so named for the two german mathematicians that discovered it: Carl Runge and Martin Kutta. This is not to suggest that this is automatically “the best” integrator for all applications (it’s not), or that you should always use this integrator over other methods listed above (you shouldn’t).

But it is one of the more accurate general purpose integration techniques available. Read on for the details of how it works.

## Implementing RK4 is not as hard as it looks

I could present to you RK4 in form of general mathematical equations which you could use to integrate some function using its derivative f(x,t) as is usually done, but seeing as my target audience for this article are programmers, not mathematicians, I will explain using code instead. From my point of view, processes like this are best described in code anyway.

So before we go any further I will define the state of an object as a struct in C++ so that we have both position and velocity values conveniently stored in one place.

        struct State
        {
            float x;      // position
            float v;      // velocity
        };

We’ll also need a struct to store the derivatives of the state values so we can easily pass them around to functions. The derivatives we store are velocity and acceleration:

        struct Derivative
        {
            float dx;      // dx/dt = velocity
            float dv;      // dv/dt = acceleration
        };

The final piece of the puzzle that we need to implement the RK4 integrator is a function that can advance the physics state ahead from t to t+dt using one set of derivatives, then once there, recalculate the derivatives using this new state. This routine is the heart of the RK4 integrator and when implemented in C++ it looks like this:

        Derivative evaluate( const State & initial, 
                             float t, 
                             float dt, 
                             const Derivative & d )
        {
            State state;
            state.x = initial.x + d.dx*dt;
            state.v = initial.v + d.dv*dt;

            Derivative output;
            output.dx = state.v;
            output.dv = acceleration( state, t+dt );
            return output;
        }

It is absolutely critical that you understand what this method is doing. First it takes the current state of the object (its position and velocity) and advances it ahead dt seconds using an Euler Integration step with the derivatives that were passed in (velocity and acceleration). Once this new position and velocity are calculated, it calculates new derivatives at this point in time using the integrated state. These derivatives will be different to the derivatives that were initially passed in to the method if the derivatives are not constant over the timestep.

In order to calculate the derivatives it copies the current state velocity into the derivative struct (this is the trick to doing position and velocity integration simultaneously) then it calls the acceleration function to calculate the acceleration for the current state at the time t+dt. The acceleration function is what drives the entire simulation and in the example source code for this article I define it as follows:

        float acceleration( const State & state, float t )
        {
            const float k = 10;
            const float b = 1;
            return -k * state.x - b*state.v;
        }

This method calculates a spring and damper force and returns it as the acceleration assuming unit mass. What you write here of course is completely simulation dependent, but it is crucial that you structure your simulation in such a way that it can calculate the acceleration or force derivatives completely from inside this method given the current state and time, otherwise your simulation cannot work with the RK4 integrator.

Finally we get to the integration routine itself which integrates the state ahead from t to t+dt using RK4:

        void integrate( State & state, 
                        float t, 
                        float dt )
        {
            Derivative a,b,c,d;

            a = evaluate( state, t, 0.0f, Derivative() );
            b = evaluate( state, t, dt*0.5f, a );
            c = evaluate( state, t, dt*0.5f, b );
            d = evaluate( state, t, dt, c );

            float dxdt = 1.0f / 6.0f * 
                ( a.dx + 2.0f * ( b.dx + c.dx ) + d.dx );
            
            float dvdt = 1.0f / 6.0f * 
                ( a.dv + 2.0f * ( b.dv + c.dv ) + d.dv );

            state.x = state.x + dxdt * dt;
            state.v = state.v + dvdt * dt;
        }

Notice the multiple calls to evaluate that make up this routine. RK4 samples derivatives four times to detect curvature instead of just once in Euler integration. The important thing to understand is how it actually does this sampling.

If you look at the code above it should be clear what is going on. Notice how it uses the previous derivative when calculating the next one. When calculating derivative b it steps ahead from t to t+dt*0.5 using derivative a, then to calculate c it steps ahead using derivative b, and finally d is calculated by stepping ahead with c. This feedback of the current derivative into the calculation of the next one is what gives the RK4 integrator its accuracy.

Once the four derivative samples have been evaluated, the best overall derivative is calculated using a weighted sum of the derivatives which comes from the Taylor Series expansion. This single value can then be used to advance the position and velocity over dt as we did before in the Euler integrator.

Notice that even when using a complicated integrator such as RK4, it all boils down into something = something + change in something * change in time. This is because differentiation and integration are fundamentally linear operations. For now we are just integrating single values, but rest assured that it all ends up like this when integrating vectors or even quaternions for rotational dynamics.

## Conclusion

(todo: clean this up, this conclusion is poorly written)

I have demonstrated how to implement an RK4 integrator for a basic physics simulation. At this point if you are serious about learning game physics you should study the example source code that comes with this article and play around with it.

Here are some ideas for study:

Switch from integrating velocity directly from acceleration to integrating momentum from force instead (the derivative of momentum is force). You will need to add “mass” and “inverseMass” to the State struct and I recommend adding a method called “recalculate” which updates velocity = momentum * inverseMass whenever it is called. Every time you modify the momentum value you need to recalculate the velocity. You should also rename the acceleration method to “force”. Why do this? Later on when working with rotational dynamics you will need to work with angular momentum directly instead of angular velocity, so you might as well start now.
Try modifying the integrate method to implement an Euler integrator. Compare the results of the simulation against the RK4 integrator. How much can you increase the spring constant k before the simulation explodes with Euler? How large can you make it with RK4?
Extend position, velocity and force to 3D quantities using vectors. If you use your intuition you should easily be able to extend the RK4 integrator to do this.