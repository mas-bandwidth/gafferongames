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
    ip_string := ip2.String()
    result := strings.Split( ip_string, "." )
    if ( len(result) == 4 ) {
        return result[0] + "." + result[1] + "." + result[2] + ".*", nil
    } else {
        return ip_string, nil
    }
}

func FuckOffAndBan( writer http.ResponseWriter, redis_client *redis.Client, from_ip string ) {
    writer.WriteHeader( http.StatusOK )
    writer.Write( []byte( "NOPE" ) )
    redis_client.Set( "banned-" + from_ip, "1", time.Hour * 24 );
}

func Log(format string, a ...interface{}) {
    time := time.Now()
    fmt.Printf( "[%d-%02d-%02d %02d:%02d:%02d] ", time.Year(), time.Month(), time.Day(), time.Hour(), time.Minute(), time.Second())
    fmt.Printf( format + "\n", a... )
}

func LogAccess( redis_client *redis.Client, from_ip string, filename string, bytes_read int64, file_size int64 ) {

    fraction_read_key := "fraction_read-" + from_ip + "-" + filename

    total_bytes_read_result, err:= redis_client.Get( "bytes_read-" + from_ip ).Result(); check( err )
    total_bytes_read, err := strconv.ParseInt( total_bytes_read_result, 10, 0 ); check( err )

    fraction_read_result, err := redis_client.Get( fraction_read_key ).Result(); check( err )
    fraction_read, err := strconv.ParseFloat( fraction_read_result, 10 ); check( err )

    if ( bytes_read > 100 ) {
        Log( "%s: %s | %d | %d/%d | %.2f", from_ip, filename, total_bytes_read, bytes_read, file_size, fraction_read )
    }
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
    from_ip, err := ParseIP( from ); check( err )

    banned_result, err := redis_client.Get( "banned-" + from_ip ).Result()
    if ( banned_result != "" ) {
        Log( "%s: Banned", from_ip );
        FuckOffAndBan( writer, redis_client, from_ip )
        return
    }

    filename := "./videos/" + vars["file"] + "." + vars["extension"]
    
    fraction_read_key := "fraction_read-" + from_ip + "-" + filename

    bytes_read_result, err := redis_client.Get( "bytes_read-" + from_ip ).Result()
    bytes_read, err := strconv.ParseInt( bytes_read_result, 10, 0 )
    if ( bytes_read > 1000*1000*1000 ) {
        Log( "%s: Too many bytes read: %d", from_ip, bytes_read )
        FuckOffAndBan( writer, redis_client, from_ip )
        return
    }

    fraction_read_result, err := redis_client.Get( fraction_read_key ).Result()
    fraction_read, err := strconv.ParseFloat( fraction_read_result, 10 )
    if ( fraction_read > 10.0 ) {
        Log( "%s: File downloaded too many times: %s (%f)", from_ip, filename, fraction_read )
        FuckOffAndBan( writer, redis_client, from_ip )
        return
    }

    f, err := os.Open( filename );
    if ( err != nil ) {
        writer.WriteHeader( http.StatusNotFound )
        return
    }
    file_info, err := f.Stat(); check( err )    
    defer f.Close()

    var video_file = VideoFile{ f, 0 }

    http.ServeContent( writer, request, filename, file_info.ModTime(), &video_file )

    last_access_key := "last_access-" + from_ip + "-" + filename

    fraction := float64( video_file.bytes_read ) / float64( file_info.Size() )

    if ( video_file.bytes_read > 100 && ( video_file.bytes_read < 1024*1024 || fraction < 0.25 ) ) {
        time.Sleep(10 * time.Second )
        redis_client.Expire( last_access_key, time.Second * 10 )
        redis_client.Incr( last_access_key )
        last_access_result, _ := redis_client.Get( last_access_key ).Result()
        if ( last_access_result == "" ) {
            Log( "%s: Smartass partial read. Bumping fraction to 1.0", from_ip )
            fraction = 1.0
        }
    }

    redis_client.Expire( "bytes_read-" + from_ip, time.Hour * 24 )
    redis_client.IncrBy( "bytes_read-" + from_ip, video_file.bytes_read )
    redis_client.Expire( fraction_read_key, time.Hour )
    redis_client.IncrByFloat( fraction_read_key, fraction )

    LogAccess( redis_client, from_ip, filename, video_file.bytes_read, file_info.Size() )
}

func main() {
    router := mux.NewRouter()
    router.HandleFunc( "/videos/{file}.{extension}", VideoHandler )
    log.Fatal( http.ListenAndServe( ":" + strconv.Itoa(Port), router ) )
}
