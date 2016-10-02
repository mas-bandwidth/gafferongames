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

A physics simulation works by making many small predictions based on the laws of physics. These predictions are actually quite simple, and basically boil down to something like "the object is here, and is traveling this fast in that direction, so in a short amount of time it should be over there". We perform these predictions using a mathematical technique called integration.

Exactly how to implement this integration is the subject of this article.

## Integrating the Equations of Motion

You may remember from high school or university physics that force equals mass times acceleration. 

        f = ma

We can switch this around to see that acceleration is force divided by mass. This makes sense because the more an object weighs, the less acceleration it receives from the same amount of force. Heavier objects are harder to throw.

        a = f/m

Acceleration is the rate of change in velocity over time:

        dv/dt = a = F/m

Similarly, velocity is the rate of change in position over time:

        dx/dt = v

This means if we know the current position and velocity of an object, and the forces that will be applied to it, we can integrate to find its position and velocity at some time in the future.

## Numerical Integration

For those who have not formally studied differential equations at university, take heart for you are in just as good a position as those who have! This is because we are not going to solve the differential equations as you would normally do in first year mathematics, instead we are going to **numerically integrate** to find the solution.

Here is how numerical integration works. First, start at an initial position and velocity, then take a small step forward to find the velocity and position at a future time. Then repeat this, moving forward in small discrete time steps, using the result of the previous calculation as the starting point for the next.

But how do we find the change in velocity and position at each step? 

The answer lies in the **equations of motion**. 

Let's call our current time **t**, and the time step **dt** or 'delta time'.

Now we can put the equations of motion in a form that anyone can understand:

        acceleration = force / mass
        
        change in position = velocity * dt

        change in velocity = acceleration * dt
        
This makes intuitive sense because if you're traveling 60 kilometers per-hour in a car, in one hour you'll be 60 kilometers further down the road. Similarly, a car accelerating 10 kilometers per-hour per-second travels 100 kilometers per-hour faster after 10 seconds.

Of course this logic only holds when acceleration and velocity are constant. But even when they're not, it's still a decent approximation to start with.

Let's put this into code. Starting with a stationary object at the origin weighing one kilogram, we apply a constant force of 10 newtons and step forward with time steps of one second:

        double t = 0.0;
        float dt = 1.0f;

        float velocity = 0.0f;
        float position = 0.0f;
        float force = 10.0f;
        float mass = 1.0f;

        while ( t <= 10.0 )
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

## Explicit Euler

What we just did is a type of Euler Integration called **explicit euler**.

To save you future embarrassment, I must point out now that Euler is pronounced "Oiler" not "yew-ler" as it is the last name of the Swiss mathematician [Leonhard Euler](https://en.wikipedia.org/wiki/Leonhard_Euler) who first discovered this technique.

Euler integration is the most basic numerical integration technique. It is only 100% accurate when the rate of change is constant over the timestep.

Since acceleration is constant in the example above, the integration of velocity is without error. However, we are also integrating velocity to get the position each step, and velocity is increasing due to acceleration. This means there is error in the integrated position.

Just how large is this error? Let's find out!

There is a closed form solution[*](#ballistic_footnote) for how an object moves under constant acceleration. We can use this to compare our numerically integrated position with the exact result:

        s = ut + 0.5at^2
        s = 0.0*t + 0.5at^2
        s = 0.5(10)(10^2)
        s = 0.5(10)(100)
        s = 500 meters

After 10 seconds, the object should have moved 500 meters, but euler integration gave a result of 450 meters. That's 50 meters off after just 10 seconds! 

This sounds really, really bad, but it's not common for games to step physics forward with such large time steps. In fact, physics usually steps forward at something closer to the display framerate.

Stepping forward with **dt** = 1/100 gives a result much closer to the exact value:

        t=9.90:     position = 489.552155     velocity = 98.999062
        t=9.91:     position = 490.542145     velocity = 99.099060
        t=9.92:     position = 491.533142     velocity = 99.199059
        t=9.93:     position = 492.525146     velocity = 99.299057
        t=9.94:     position = 493.518127     velocity = 99.399055
        t=9.95:     position = 494.512115     velocity = 99.499054
        t=9.96:     position = 495.507111     velocity = 99.599052
        t=9.97:     position = 496.503113     velocity = 99.699051
        t=9.98:     position = 497.500092     velocity = 99.799049
        t=9.99:     position = 498.498077     velocity = 99.899048
        t=10.00:    position = 499.497070     velocity = 99.999046

As you can see, this is a pretty good result. Certainly good enough for a game.

## Why Euler Integration is not (always) so great

However, there are cases where explicit euler integration breaks down.

<img src="/img/game_physics/spring_damper_explicit_euler.png" width="100%"/>

<img src="/img/game_physics/spring_damper_implicit_euler.png" width="100%"/>

## Many different integration methods exist

Semi-implicit euler (symplectic euler) integrates velocity first before integrating position:

        while ( t <= 10.0 )
        {
            velocity = velocity + ( force / mass ) * dt;
            position = position + velocity * dt;
            t = t + dt;
        }

This small change makes the integrator much more stable than explicit euler. (todo: link to wikipedia page for reasoning. also link to symplectic integrator page). Most commercial physics engines use this integrator.

A completely different option is [implicit euler](http://web.mit.edu/10.001/Web/Course_Notes/Differential_Equations_Notes/node3.html). This method is better for simulating stiff equations that become unstable with other methods, but requires numerically solving a system of equations per-timestep. It's not often used in game physics.

Another option for greater accuracy and less memory when simulating a large number of particles is [verlet integration](https://en.wikipedia.org/wiki/Verlet_integration), specifically velocity-less verlet integration. This integrator does not require storing velocity per-particle, as it can derive velocity from the two most recent position values. This makes collision response and position fix-up easy to implement and saves memory when you have lots of particles.

(todo: don't "focus on RK4 for the rest of the article". explore it. lets compare it with semi-implicit euler and see which one comes out on top. beg the question. don't state that it's better. it's not automatically. in fact, it's *not* actually better for games in general)

There are many other integrators to consider: _(todo: list them with links to wikipedia pages)_. However, for the rest of this article I’m going to focus on the Runge Kutta order 4 or "RK4". So named for the two German physicists who discovered it: [Carl Runge](https://en.wikipedia.org/wiki/Carl_David_Tolmé_Runge) and [Martin Kutta](https://en.wikipedia.org/wiki/Martin_Wilhelm_Kutta). 

This is not to suggest that RK4 is automatically the "best" integrator for all applications _(there's no such thing)_, or that you should always use this integrator over the others listed above _(you shouldn’t)_. But it is one of the most accurate general purpose integration techniques available. 

## Implementing RK4 is not as hard as it looks

I could present to you RK4 in form of general mathematical equations, but seeing as my target audience for this article are programmers, not mathematicians, I will explain using code instead.

So before we go any further let's define the state of an object as a struct in C++ so that we have both position and velocity values conveniently stored in one place:

        struct State
        {
            float x;      // position
            float v;      // velocity
        };

We also need a struct to store the derivatives of the state values:

        struct Derivative
        {
            float dx;      // dx/dt = velocity
            float dv;      // dv/dt = acceleration
        };

Next we need a function to advance the physics state ahead from t to t+dt using one set of derivatives, and once there recalculate the derivatives at this new state: 

        Derivative evaluate( const State & initial, 
                             double t, 
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

The acceleration function is what drives the entire simulation and in the example source code for this article it calculates a spring and damper force and returns it as the acceleration assuming unit mass:

        float acceleration( const State & state, double t )
        {
            const float k = 10;
            const float b = 1;
            return -k * state.x - b * state.v;
        }

What you write here is of course simulation dependent, but you must structure your simulation so you can calculate the acceleration inside this method given the current state and time, otherwise it will not work with the RK4 integrator.

Finally we get to the integration routine itself:

        void integrate( State & state, 
                        double t, 
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

Notice how it uses the previous derivative when calculating the next: derivative a is used when calculating b, b is used when calculating c, and so on. This feedback of the current derivative into the calculation of the next is what gives the RK4 integrator its accuracy.

Importantly, each these derivatives will typically be _different_ when the rate of change in these quantities is a function of time or of the state itself. For example, a Hooke's law spring force which is a function of the current position, or a drag force which is a function of the current velocity.

Once the four derivatives have been evaluated, the best overall derivative is calculated as a weighted sum that is derived from the [Taylor Series](https://en.wikipedia.org/wiki/Taylor_series) expansion. Details [here](https://en.wikipedia.org/wiki/Runge–Kutta_methods#Derivation_of_the_Runge.E2.80.93Kutta_fourth-order_method). This combined derivative is then used to advance the position and velocity forward, just like we did with the explicit euler integrator.

(todo: weak sentence below, rework, and show the result of the RK4 integrator on the spring damper system as a graph)

Even when using a relatively complicated integrator such as RK4, it all boils down in the end to something += rate of change * dt. This is because differentiation and integration are fundamentally linear operations. For now we are just integrating scalar values, but rest assured it still ends up like this when integrating vectors or even quaternions for rotational dynamics.

## Conclusion

_(todo: clean this up, this conclusion is poorly written)_

I have demonstrated how to implement an RK4 integrator for a basic physics simulation. At this point if you are serious about learning game physics you should study the example source code that comes with this article and play around with it.

Here are some ideas for study:

Switch from integrating velocity directly from acceleration to integrating momentum from force instead (the derivative of momentum is force). You will need to add “mass” and “inverseMass” to the State struct and I recommend adding a method called “recalculate” which updates velocity = momentum * inverseMass whenever it is called. Every time you modify the momentum value you need to recalculate the velocity. You should also rename the acceleration method to “force”. Why do this? Later on when working with rotational dynamics you will need to work with angular momentum directly instead of angular velocity, so you might as well start now.
Try modifying the integrate method to implement an Euler integrator. Compare the results of the simulation against the RK4 integrator. How much can you increase the spring constant k before the simulation explodes with Euler? How large can you make it with RK4?
Extend position, velocity and force to 3D quantities using vectors. If you use your intuition you should easily be able to extend the RK4 integrator to do this.

<a name="ballistic_footnote"></a> _\* It's tempting to see this closed form and think "Hey, why don't I just use this as the integrator!". While it is 100% accurate under constant acceleration, this is not useful in the general case because acceleration is not usually constant. Consider: drag forces (function of velocity), spring forces (function of position), and forces that are a function of time. All of these result in non-constant acceleration._
