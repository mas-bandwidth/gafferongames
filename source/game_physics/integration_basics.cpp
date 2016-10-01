#include <stdio.h>

void explicit_euler_constant_acceleration( float dt ) 
{
    // todo: write out to text file

    double t = 0.0;
    float velocity = 0.0f;
    float position = 0.0f;
    float force = 10.0f;
    float mass = 1.0f;

    while ( t <= 10.0 )
    {
        printf( "t=%.2f: position = %f, velocity = %f\n", t, position, velocity );
        position = position + velocity * dt;
        velocity = velocity + ( force / mass ) * dt;
        t += dt;
    }
}

void explicit_euler_spring_damper( float dt, float k, float b )
{
    // todo: write out to csv file

    double t = 0.0;
    float velocity = 0.0f;
    float position = 1000.0f;
    float mass = 1.0f;

    while ( t <= 100.0 )
    {
        printf( "%.2f,%f,%f\n", t, position, velocity );
        
        const float force = -k * position - b * velocity;

        position = position + velocity * dt;
        velocity = velocity + ( force / mass ) * dt;
        t += dt;
    }
}

void implicit_euler_spring_damper( float dt, float k, float b )
{
    // todo: write out to csv file

    double t = 0.0;
    float velocity = 0.0f;
    float position = 10000.0f;
    float mass = 1.0f;

    while ( t <= 100.0 )
    {
        printf( "%.2f,%f,%f\n", t, position, velocity );
        
        const float force = -k * position - b * velocity;

        velocity = velocity + ( force / mass ) * dt;
        position = position + velocity * dt;
        t += dt;
    }
}

int main()
{
    explicit_euler_constant_acceleration( 1.0f );

    explicit_euler_constant_acceleration( 0.01f );

    explicit_euler_spring_damper( 0.01f, 100.0f, 0.1f );

    implicit_euler_spring_damper( 0.01f, 100.0f, 0.1f );

    return 0;

}
