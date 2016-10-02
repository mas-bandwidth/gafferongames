#include <stdio.h>
#include <math.h>

void explicit_euler_constant_acceleration( const char * filename, float dt ) 
{
    FILE * file = fopen( filename, "w" );
    if ( !file )
        return;

    double t = 0.0;
    float velocity = 0.0f;
    float position = 0.0f;
    float force = 10.0f;
    float mass = 1.0f;

    while ( t <= 10.0 )
    {
        fprintf( file, "t=%.2f: position = %f, velocity = %f\n", t, position, velocity );
        position = position + velocity * dt;
        velocity = velocity + ( force / mass ) * dt;
        t += dt;
    }

    printf( "wrote %s\n", filename );

    fclose( file );
}

void explicit_euler_spring_damper( const char * filename, float dt, float k, float b )
{
    FILE * file = fopen( filename, "w" );
    if ( !file )
        return;

    fprintf( file, "time,position,velocity\n" );

    double t = 0.0;
    float velocity = 0.0f;
    float position = 1000.0f;
    float mass = 1.0f;

    while ( t <= 100.0 )
    {
        fprintf( file, "%.2f,%f,%f\n", t, position, velocity );
        
        const float force = -k * position - b * velocity;

        position = position + velocity * dt;
        velocity = velocity + ( force / mass ) * dt;
        t += dt;
    }

    printf( "wrote %s\n", filename );

    fclose( file );
}

void implicit_euler_spring_damper( const char * filename, float dt, float k, float b )
{
    FILE * file = fopen( filename, "w" );
    if ( !file )
        return;

    fprintf( file, "time,position,velocity\n" );

    double t = 0.0;
    float velocity = 0.0f;
    float position = 1000.0f;
    float mass = 1.0f;

    while ( t <= 100.0 )
    {
        fprintf( file, "%.2f,%f,%f\n", t, position, velocity );
        
        const float force = -k * position - b * velocity;

        velocity = velocity + ( force / mass ) * dt;
        position = position + velocity * dt;
        t += dt;
    }

    printf( "wrote %s\n", filename );

    fclose( file );
}

struct State
{
    float x;      // position
    float v;      // velocity
};

struct Derivative
{
    float dx;      // dx/dt = velocity
    float dv;      // dv/dt = acceleration

    Derivative() { dx = 0; dv = 0; }
};

static float rk4_k = 10.0f;
static float rk4_b = 0.1f;

float acceleration_rk4( const State & state, double t )
{
    return -rk4_k * state.x - rk4_b * state.v;
}

Derivative evaluate_rk4( const State & initial, double t, float dt, const Derivative & d )
{    
    State state;
    state.x = initial.x + d.dx*dt;
    state.v = initial.v + d.dv*dt;

    Derivative output;
    output.dx = state.v;
    output.dv = acceleration_rk4( state, t+dt );

    return output;
}
void integrate_rk4( State & state, double t, float dt )
{
    Derivative a,b,c,d;

    a = evaluate_rk4( state, t, 0.0f, Derivative() );
    b = evaluate_rk4( state, t, dt*0.5f, a );
    c = evaluate_rk4( state, t, dt*0.5f, b );
    d = evaluate_rk4( state, t, dt, c );

    float dxdt = 1.0f / 6.0f * 
        ( a.dx + 2.0f * ( b.dx + c.dx ) + d.dx );
    
    float dvdt = 1.0f / 6.0f * 
        ( a.dv + 2.0f * ( b.dv + c.dv ) + d.dv );

    state.x = state.x + dxdt * dt;
    state.v = state.v + dvdt * dt;
}

void rk4_spring_damper( const char * filename, float dt, float k, float b )
{
    FILE * file = fopen( filename, "w" );
    if ( !file )
        return;

    rk4_k = k;
    rk4_b = b;

    fprintf( file, "time,position,velocity\n" );

    double t = 0.0;

    State state;
    state.x = 1000.0f;
    state.v = 0.0f;

    while ( t <= 100.0 )
    {
        fprintf( file, "%.2f,%f,%f\n", t, state.x, state.v );

        integrate_rk4( state, t, dt );
        
        t += dt;
    }

    printf( "wrote %s\n", filename );

    fclose( file );
}

void exact_spring_undamped( const char * filename, float dt, float k )
{
    // From https://www.ncsu.edu/crsc/events/ugw05/slides/root_harmonic.pdf

    FILE * file = fopen( filename, "w" );
    if ( !file )
        return;

    fprintf( file, "time,position\n" );

    double t = 0.0;

    const float m = 1.0f;
    const float y0 = 1000.0f;
    const float w0 = (float) sqrt( k / m );

    while ( t <= 100.0 )
    {
        const float y = y0 * cos( w0 * t );

        fprintf( file, "%.2f,%f\n", t, y );

        t += dt;
    }

    printf( "wrote %s\n", filename );

    fclose( file );
}

int main()
{
    const float k = 15.0f;
    const float b = 0.1f;

    // explicit euler

    explicit_euler_constant_acceleration( "explicit_euler_constant_acceleration_1fps.txt", 1.0f );

    explicit_euler_constant_acceleration( "explicit_euler_constant_acceleration_100fps.txt", 0.01f );

    explicit_euler_spring_damper( "explicit_euler_spring_damper_100fps.csv", 0.01f, k, b );

    // implicic euler

    implicit_euler_spring_damper( "implicit_euler_spring_damper_100fps.csv", 0.01f, k, b );

    implicit_euler_spring_damper( "implicit_euler_spring_undamped_100fps.csv", 0.01f, k, 0.0f );

    implicit_euler_spring_damper( "implicit_euler_spring_undamped_10fps.csv", 0.1f, k, 0.0f );

    // rk4

    rk4_spring_damper( "rk4_spring_damper_100fps.csv", 0.01f, k, b );

    rk4_spring_damper( "rk4_spring_undamped_100fps.csv", 0.01f, k, 0.0f );

    rk4_spring_damper( "rk4_spring_undamped_10fps.csv", 0.1f, k, 0.0f );

    // exact solution

    exact_spring_undamped( "exact_spring_undamped_100fps.csv", 0.01f, k );    

    exact_spring_undamped( "exact_spring_undamped_10fps.csv", 0.01f, k );    

    return 0;
}
