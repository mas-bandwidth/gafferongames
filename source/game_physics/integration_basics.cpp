#include <stdio.h>

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

int main()
{
    explicit_euler_constant_acceleration( "explicit_euler_constant_acceleration_dt_1.0.txt", 1.0f );

    explicit_euler_constant_acceleration( "explicit_euler_constant_acceleration_dt_0.01.txt", 0.01f );

    explicit_euler_spring_damper( "explicit_euler_spring_damper.csv", 0.01f, 15.0f, 0.1f );

    implicit_euler_spring_damper( "implicit_euler_spring_damper.csv", 0.01f, 15.0f, 0.1f );

    rk4_spring_damper( "rk4_spring_damper.csv", 0.01f, 15.0f, 0.1f );

    rk4_spring_damper( "rk4_spring_no_damping.csv", 0.01f, 15.0f, 0.0f );

    implicit_euler_spring_damper( "implicit_euler_spring_no_damping.csv", 0.01f, 15.0f, 0.0f );

    rk4_spring_damper( "rk4_spring_no_damping_dt_0.1.csv", 0.1f, 15.0f, 0.0f );

    implicit_euler_spring_damper( "implicit_euler_spring_no_damping_dt_0.1.csv", 0.1f, 15.0f, 0.0f );

    rk4_spring_damper( "rk4_spring_no_damping_dt_0.25.csv", 0.25f, 15.0f, 0.0f );

    implicit_euler_spring_damper( "implicit_euler_spring_no_damping_dt_0.25.csv", 0.25f, 15.0f, 0.0f );

    rk4_spring_damper( "rk4_spring_no_damping_dt_1.0.csv", 0.25f, 15.0f, 0.0f );

    implicit_euler_spring_damper( "implicit_euler_spring_no_damping_dt_1.0.csv", 0.25f, 15.0f, 0.0f );

    return 0;
}
