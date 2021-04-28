package main

import (
    "fmt"
    "time"
)

func main() {

    c1 := make(chan string, 1)
    go func() {
        c1 <- "result 1"
    }()

    go func() {
      time.Sleep(1 * time.Second)
      select {
      case c1 <- "result 2":
        fmt.Println("udalo sie wyslac")
      case <-time.After(2 * time.Second):
        fmt.Println("nie udalo sie wyslac")
      }
    }()
    fmt.Println("czekam")
    time.Sleep(10 * time.Second)
    fmt.Println("im out")
    res := <-c1
    fmt.Println(res)
}
