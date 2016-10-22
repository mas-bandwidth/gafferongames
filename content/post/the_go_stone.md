+++
categories = ["Virtual Go"]
tags = ["physics","networking","go/baduk/weiqi"]
date = "2013-09-18"
title = "The Go Stone"
description = "Modelling the shape of a biconvex go stone"
draft = false
+++

## Introduction

Hi, I'm Glenn Fiedler. Welcome to [**Virtual Go**](/categories/virtual-go/), my project to create a physically accurate computer simulation of a Go board and stones.

If you've ever played Go, you know that a biconvex go stone has an interesting wobble when placed on the board. This wobble is a direct consequence of its unique shape. 

I'd like to reproduce this wobble in Virtual Go, so we're going to spend some time studying the shape of Go stones, in order to capture and simulate this wobble inside a computer :)

## Slate And Shell

In Japan, Go stones are traditionally made out of slate and clam shell. 

They are quite beautiful.

<img src="/img/virtualgo/slate-and-shell-in-ko.jpg" alt="slate and shell in ko" width="100%"/>

Clam shell stones come in several grades of quality. The highest being yuki or "snow" grade with fine, regularly spaced lines.

Go stones also come in different sizes. The thicker the stone, the more expensive it is, as only a small portion of the clam shell is suitable for making the larger stones.

<img src="/img/virtualgo/go-stone-side-profile-sizes.png" alt="go stone side profile sizes" width="100%"/>

At first glance the go stone looks like it is an ellipse, but side-on you can see this is not the case. This shape is called a _biconvex solid_. I find this shape interesting because it is the intersection of two spheres.

We can study this shape by looking at the intersection of two circles:

<img src="/img/virtualgo/biconvex.gif" alt="biconvex" width="75%"/>

I quickly noticed that by varying the radius of the circles and the distance between their centers, I could generate go stones of different sizes.

This is interesting, but when I'm creating a go stone I don't really want it to be parameterized this way. Instead I'd like to say, "Hey, I would like a stone of this width and height" and have a function that calculates the radius of the circles and how far apart they should be.

To write this function we first need to do some math:

<a href="http://gafferongames.com/wp-content/uploads/2013/02/biconvex-unknowns-take-2.png"><img src="http://gafferongames.com/wp-content/uploads/2013/02/biconvex-unknowns-take-2.png" alt="biconvex unknowns - take 2" width="455" height="657" class="size-full wp-image-2299" /></a>

First notice that the point Q lies on the generating circle, so the line CQ has length r:

[latex size="2"]d + h/2 = r[/latex]
[latex size="2"]d = r - h/2[/latex]

The point P is also on the generating circle so the green line CP has length r as well. Using Pythagoras theorem and substituting for d:

[latex size="2"]r^2 = d^2 + (w/2)^2[/latex]
[latex size="2"]r^2 = ( r - h/2 )^2 + (w/2)^2[/latex]
[latex size="2"]r^2 = ( h^2/4 - hr + r^2 ) + w^2/4[/latex]
[latex size="2"]r^2 = h^2/4 - hr + r^2 + w^2/4[/latex]
[latex size="2"]0 = h^2/4 - hr + 0 + w^2/4[/latex]
[latex size="2"]hr = h^2/4 + w^2/4[/latex]
[latex size="2"]r = ( h^2 + w^2 ) / 4h[/latex]

Which gives us everything we need to write the function:

        void calculateBiconvex( float w,  
                                float h, 
                                float & r, 
                                float & d )
        {
            r = ( w*w + h*h ) / ( 4*h );
            d = r - h/2;
        }

Now that we can mathematically define a go stone parameterized by its width and height. There is just one problem: the edge is very sharp!

In order for our our stone to be aesthetically pleasing we need to round off the edge with a bevel.

<a href="http://gafferongames.com/wp-content/uploads/2013/02/go-stone-smooth-bevel.jpg"><img class="size-large wp-image-1847" alt="go-stone-smooth-bevel" src="http://gafferongames.com/wp-content/uploads/2013/02/go-stone-smooth-bevel-1024x575.jpg" width="700" height="438" /></a>

Let's parameterize the bevel by its height b:

<a href="http://gafferongames.com/wp-content/uploads/2013/02/bevel-b.gif"><img class="size-full wp-image-1856" alt="bevel-b" src="http://gafferongames.com/wp-content/uploads/2013/02/bevel-b.gif" width="492" height="669" /></a>

In three dimensions the bevel is actually a torus (donut) around the edge of the go stone. We need to calculate the major and minor radii r<sub>1</sub> and r<sub>2</sub> of the torus as a function of b and the dimensions of the go stone:

<a href="http://gafferongames.com/wp-content/uploads/2013/02/bevel-math-1.gif"><img class="size-large wp-image-1858" alt="bevel-math-1" src="http://gafferongames.com/wp-content/uploads/2013/02/bevel-math-1-1024x794.gif" width="700" height="543" /></a>

The key to solving this is to realize that if the go stone and the bevel are to match perfectly then the tangent of the two circles must be equal at the point P.

<a href="http://gafferongames.com/wp-content/uploads/2013/02/bevel-math-2.gif"><img class="size-full wp-image-1876" alt="bevel-math-2" src="http://gafferongames.com/wp-content/uploads/2013/02/bevel-math-2.gif" width="700" height="543" /></a>

If the tangent is equal then the normal must be equal as well. This means that the center of the bevel circle lies at the intersection of the line CP and the x axis. 

We already know C so if we can find the point P then we can find this intersection point. Once we know the intersection point we can find r<sub>1</sub> and r<sub>2</sub>.

Since P is at the start of the bevel:

[latex size="2"]P_y = b/2[/latex]

Because P lies on the biconvex circle with center C and radius r we can use the equation of the circle to find x as a function of y:

[latex size="2"]x^2 + y^2 = r^2[/latex]
[latex size="2"]x = \sqrt{ r^2 - y^2 }[/latex]

We need y relative to the circle center C, not in go stone coordinates, so we add d and substitute y' for y:

[latex size="2"]y' = b/2 + d[/latex]
[latex size="2"]P_x = \sqrt{ r^2 - ( b/2 + d )^2 }[/latex]

We can now find r<sub>1</sub> by similar triangles:

[latex size="2"]r_1/P_x = d / ( d + b/2 )[/latex]
[latex size="2"]r_1 = P_x d / ( d + b/2 )[/latex]

and q by Pythagoras theorem:

[latex size="2"]q^2 = d^2 + r_1^2[/latex]
[latex size="2"]q = \sqrt{ d^2 + r_1^2 }[/latex]

Because line CP has length r and substituting for q:

[latex size="2"]q + r_2 = r[/latex]
[latex size="2"]r_2 = r - q[/latex]
[latex size="2"]r_2 = r - \sqrt{ d^2 + r_1^2 }[/latex]

Now we have everything we need to write the function:

        void calculate_bevel( float r, float d, float b, 
                              float & r1, float & r2 )
        {
            const float y = b/2 + d;
            const float px = sqrt( r*r - y*y );
            r1 = px * d / ( d + b/2 ); 
            r2 = r - sqrt( d*d + r1*r1 );
        }

An important note: we're only going to apply this bevel to the go stone that we render.

All physics calculations use the biconvex solid with sharp edges.

Why? The bevel is very small and it has very little effect on how the stone moves. Plus, seeing as how the go stone typically spends most of it's time wobbling about on the sphere surface, cutting a small corner here (or not) is a reasonable approximation.
