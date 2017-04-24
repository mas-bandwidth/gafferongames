package main

import (
    "os"
    "fmt"
    "log"
    "net"
    "time"
    "errors"
    "strings"
    "strconv"
    "net/http"
    "github.com/gorilla/mux"
    "github.com/go-redis/redis"
)

const Port = 8080

func check( e error ) {
    if e != nil {
        panic( e )
    }
}

func FormatRequest( r * http.Request ) string {
    var request []string
    url := fmt.Sprintf("%v %v %v", r.Method, r.URL, r.Proto)
    request = append(request, url)
    request = append(request, fmt.Sprintf("Host: %v", r.Host))
    for name, headers := range r.Header {
        name = strings.ToLower(name)
        for _, h := range headers {
            request = append(request, fmt.Sprintf("%v: %v", name, h))
        }
    }
 
    if r.Method == "POST" {
        r.ParseForm()
        request = append(request, "\n")
        request = append(request, r.Form.Encode())
    } 
    return strings.Join(request, "\n")
}

type VideoFile struct {
    file        *os.File 
    bytes_read  int64
}

func ( video_file *VideoFile ) Read( p []byte ) (int, error) {
    bytes, err := video_file.file.Read( p )
    video_file.bytes_read += int64( bytes )
    return bytes, err
}

func ( video_file *VideoFile ) Seek( offset int64, whence int ) (int64, error) {
    return video_file.file.Seek( offset, whence )
}

func ParseIP( s string ) ( string, error ) {
    ip, _, err := net.SplitHostPort(s)
    if err == nil {
        return ip, nil
    }
    ip2 := net.ParseIP(s)
    if ip2 == nil {
        return "", errors.New("invalid IP")
    }
    return ip2.String(), nil
}

func FuckOffAndBan( writer http.ResponseWriter, redis_client *redis.Client, from_ip string ) {
    writer.WriteHeader( http.StatusOK )
    writer.Write( []byte( "Fuck off" ) )
    redis_client.Set( "banned-" + from_ip, "1", time.Hour * 24 );
}

func VideoHandler( writer http.ResponseWriter, request * http.Request ) {

    vars := mux.Vars( request )

//    fmt.Println( "\n=======================================\n" + FormatRequest( request ) + "\n=======================================\n" )

    redis_client := redis.NewClient( &redis.Options{ Addr: "redis:6379", Password: "", DB: 0 } )

    from := request.RemoteAddr
    forwarded_for := request.Header.Get( "X-Forwarded-For" )
    if ( forwarded_for != "" ) {
        from = forwarded_for
    }
    from_ip, err := ParseIP( from )
    if ( err != nil ) { 
        fmt.Printf( "couldn't parse from IP\n" )
        return 
    }

    banned_result, err := redis_client.Get( "banned-" + from_ip ).Result()
    if ( banned_result != "" ) {
        fmt.Printf( "Banned: %s\n", from_ip );
        FuckOffAndBan( writer, redis_client, from_ip )
        return
    }

    filename := "./videos/" + vars["file"] + "." + vars["extension"]
    
    fraction_read_key := "fraction_read-" + from_ip + "-" + filename

    bytes_read_result, err := redis_client.Get( "bytes_read-" + from_ip ).Result()
    bytes_read, err := strconv.ParseInt( bytes_read_result, 10, 0 )
    if ( bytes_read > 1000*1000*1000 ) {
        fmt.Printf( "Too many bytes read: %s (%d)\n", from_ip, bytes_read )
        FuckOffAndBan( writer, redis_client, from_ip )
        return
    }

    fraction_read_result, err := redis_client.Get( fraction_read_key ).Result()
    fraction_read, err := strconv.ParseFloat( fraction_read_result, 10 )
    if ( fraction_read > 10.0 ) {
        fmt.Printf( "File downloaded too many times: %s by %s (%f)\n", filename, from_ip, fraction_read )
        FuckOffAndBan( writer, redis_client, from_ip )
        return
    }

    // todo: ^--- end pipeline

    f, err := os.Open( filename );
    if ( err != nil ) {
        writer.WriteHeader( http.StatusNotFound )
        return
    }
    file_info, err := f.Stat(); check( err )    
    defer f.Close()

    var video_file = VideoFile{ f, 0 }

    http.ServeContent( writer, request, filename, file_info.ModTime(), &video_file )

    if ( video_file.bytes_read != 0 ) {
        fmt.Printf( "%s: %s | %d | %d | %.1f\n", from_ip, filename, bytes_read, video_file.bytes_read, fraction_read )
    }

    // todo: should pipeline these guys
    redis_client.IncrBy( "bytes_read-" + from_ip, video_file.bytes_read )
    redis_client.Expire( fraction_read_key, time.Hour )
    redis_client.IncrByFloat( fraction_read_key, float64( video_file.bytes_read ) / float64( file_info.Size() ) )
}

func main() {
    router := mux.NewRouter()
    router.HandleFunc( "/videos/{file}.{extension}", VideoHandler )
    log.Fatal( http.ListenAndServe( ":" + strconv.Itoa(Port), router ) )
}
