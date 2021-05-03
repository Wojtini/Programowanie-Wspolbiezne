package main

import (
	"fmt"
  "math/rand"
  "sync"
  "time"
  "strconv"
  "os"
)

//Struktury
type node struct{
  id int
  connections[] *node
  in_connection chan *packet

  in_routing chan R_j //questionable R_j + id?
  out_routing chan int
  out_routing_resp chan R_j
  out_routing_resp_delete chan bool
}

type R_j struct{
  j int; // do ktorego noda dot. ta droga
  nexthop *node;
  cost int;
  changed bool;
}

type packet struct{
  array[] R_j
}
//End Struktuty
func printServer(output chan string){
	for{
		str := <- output
		fmt.Println(str)
	}
}

func newNode(id int,n int) *node {
  node := node{id: id}
  node.in_connection = make (chan *packet)
  //node.connections = append(node.connections,&node)
  node.in_routing = make (chan R_j)
  node.out_routing = make (chan int)
  node.out_routing_resp = make (chan R_j)
  node.out_routing_resp_delete = make (chan bool)
  return &node
}

func newPacket() *packet {
  packet := packet{}
  return &packet
}

func clonePacket(toClone *packet) *packet {
  clone := packet{}
  for i:=0;i<len(toClone.array);i++{
    clone.array = append(clone.array,toClone.array[i])
	}
  return &clone
}

func connectNodes(node_1 *node,node_2 *node) bool{
  // fmt.Println("Próba dodania",node_1.id, node_2.id)
	for i:=0;i<len(node_1.connections);i++{
		if(node_1.connections[i].id==node_2.id){
			// fmt.Println("Nieudana",node_1.connections[i].id, node_2.id)
			return false //already connected
		}
	}
  node_1.connections = append(node_1.connections,node_2)
  node_2.connections = append(node_2.connections,node_1)
  // fmt.Println("Udana")
	return true
}

func doesConnectionExist(n *node, id int) *node{
  for i:=0;i<len(n.connections);i++{
		if(n.connections[i].id==id){
			return n.connections[i]
		}
	}
  return nil
}

func endListener(entry chan int, wg *sync.WaitGroup){
  counter := 0
  defer wg.Done()
  for{
    select{
    case number := <- entry: //1 or -1 simple counter
      counter += number
    case <-time.After(10 * time.Second):
      if(counter == 0){
        return
      }
    }
  }
}
//out_packet tworzy pakiet z changed=true
//in_change robi zmiane z podanymi wartosciami
//init pierwsze info jakie dostaje i uzywa do inicjalizacji danych w routingTable
//out_packet chan *packet, in_change chan *packet_info,  chyabe jednak jest to w nodzie i useless w funkcji
func routingTable(this_node *node, n int, printOrder chan bool, endListenerChan chan int,printServer chan string){
  //inicjalizacja
  table := make([]R_j,n)

  for i:=0;i<n;i++{
    if(i == this_node.id){
      continue
    }
    node_temp := doesConnectionExist(this_node,i)
    if(node_temp != nil){
      table[i].cost = 1
      table[i].nexthop = node_temp
    }else{
      if(i > this_node.id){
        table[i].nexthop = doesConnectionExist(this_node,this_node.id + 1)
        table[i].cost = i - this_node.id
      }else if(i < this_node.id){
        table[i].nexthop = doesConnectionExist(this_node,this_node.id - 1)
        table[i].cost = this_node.id - i
      }
    }
    table[i].changed = true
    endListenerChan <- 1
    table[i].j = i
  }
  //Dla wyswietlenia
  if(this_node.id == 0){
  }
  //Faktycznie dzialanie watku
  for {
    select{
    case new_R_j := <- this_node.in_routing: //new_R_j jest wyliczany w receiver'ze, wiec nexthop i cost jest zalezny wlasnie od receiver'a
      table[new_R_j.j].nexthop = new_R_j.nexthop
      table[new_R_j.j].cost = new_R_j.cost

      if(!table[new_R_j.j].changed){
        endListenerChan <- 1 //nastapila zmiana
      }

      table[new_R_j.j].changed = true
      //i := new_R_j.j
    case index := <- this_node.out_routing:
      this_node.out_routing_resp <- table[index]
      flagchange := <- this_node.out_routing_resp_delete
      if(flagchange){
        if(table[index].changed){
          endListenerChan <- -1 //nastapila zmiana
        }
        table[index].changed = false // wyczyta tylko jak wysle wiec git
      }
    case <- printOrder:
      //tylko do debugowania printServer opuszczam
      fmt.Println("Routing Table for ",this_node.id)
      for i:=0;i<len(table);i++{
        if(i!=this_node.id){
    		  fmt.Print("{id: ",i,"przez_co:",table[i].nexthop.id,"koszt: ", table[i].cost, table[i].changed,"}")
        }else{
          fmt.Print("----------------")
        }
    	}
      fmt.Println("")
    }
  }
}

func sender(node *node, n int, start chan bool,printServer chan string){
  sendcounter := 0
  <- start
  for{
    //czekaj chwile
    time.Sleep(time.Duration(rand.Int31n(5)) * time.Second)
    //fmt.Println(node.id,"bud  ze sie")
    //tworz nowy pakiet
    perfect_packet := newPacket()

    for i:=0;i<n;i++{
      if(i==node.id){
        continue
      }
      node.out_routing <- i //popros o i-ty informacje
      resp := <- node.out_routing_resp //wez ta informacje R_j
      node.out_routing_resp_delete <- true //nie chcemy zmieniac flagi
      // if(node.id == 3){
      //   fmt.Println("Siema to ja resp",resp) // jest git
      // }
      if(resp.changed){
        resp.nexthop = node //prawda jak przesle dalej
        perfect_packet.array = append(perfect_packet.array,resp)
      }
    }
    // if(node.id == 3){
    //   fmt.Println("Array ktory chce wyslac ",packet.array) // jest git
    // }
    //teraz wyslij
    if(len(perfect_packet.array)==0){
      continue //nothing to send
    }
    sendcounter+=1
    // fmt.Println("XDDDDDDDDDDDDDDDDD",node.id, "Wyslal juz ",sendcounter)
    for i:=0;i<len(node.connections);i++{
      pom := clonePacket(perfect_packet)
      // fmt.Println(node.id, " wyslal do ", node.connections[i].id," tyle ", len(packet.array),"info")
      // if(node.id==0){
      //   fmt.Println(node.id, " wyslal", pom)
      // }
      node.connections[i].in_connection <- pom
    }
    printServer <- strconv.Itoa(node.id) + " wyslal pakiet"
    //i tyle ;)
  }
}

func receiver(node *node,printServer chan string){
  for{
    packet := <- node.in_connection

    // if(node.id == 4){
    printServer <- strconv.Itoa(node.id) + " dostal od " + strconv.Itoa(packet.array[0].nexthop.id) + " pakiet"
    //   fmt.Println("Pakiet:",packet)
    //   fmt.Println("Sprawdzam swoja tablice")
    // }
    for i:=0;i<len(packet.array);i++{
      packet.array[i].cost += 1
      node.out_routing <- packet.array[i].j
      rec_info := <- node.out_routing_resp
      node.out_routing_resp_delete <- false //tylko do porownania wiec flaga zostaje
      // if(node.id == 4){
        // fmt.Println(node.id, " sprawdza koszty do ",rec_info.j," koszty: ",rec_info.cost," a mozliwy ", packet.array[i].cost, " info zawdziecza ", packet.array[i].nexthop.id)
      // }
      if(rec_info.cost > packet.array[i].cost){
        // if(node.id == 4){
        printServer <- strconv.Itoa(node.id) + " wprowadza zmiany dla trasy do " + strconv.Itoa(packet.array[i].j) + " z kosztem " + strconv.Itoa(rec_info.cost) + "||||| Zmiany: Koszt: " + strconv.Itoa(packet.array[i].cost) + " Przez wierzholek: " + strconv.Itoa(packet.array[i].nexthop.id) + " - tez zaproponowal trase "

        // }
        node.in_routing <- packet.array[i] //zmien
      }

    }
    // if(node.id == 4){
    //   fmt.Println(node.id,"konczy sprawdzanie")
    // }
  }
}

//Variables
var max_shortcuts int = 0;
var n int = 0 // ilosc wierzcholkow
var d int = 0 // ilosc skrotow
var garbage int = 5 // nothing

func main() {
  rand.Seed(time.Now().UTC().UnixNano())


	//Print server init
	pschan := make(chan string)
	go printServer(pschan)

	//Wait group
  var wg sync.WaitGroup
  wg.Add(1)

  n,garbage := strconv.Atoi(os.Args[1])
  d,garbage := strconv.Atoi(os.Args[2])
	if(garbage!=nil){
		fmt.Println("problem occured")
	}

  max_shortcuts = (n-3)*n/3;
  if(d > max_shortcuts){
    fmt.Println("Za duzo skrotow")
    return;
  }
  fmt.Println("git")

	nodesArr := make([]*node,0)
  startChanArr := make([]chan bool,0)
  printOrder := make([]chan bool,0)
  //Create Basic nodes
	for i:=0;i<n;i++{
		a := newNode(i,n)
		nodesArr = append(nodesArr,a)
    c := make(chan bool);
    startChanArr = append(startChanArr,c)
    go sender(a,n,c,pschan)
    go receiver(a,pschan)
	}
	//Create basic connections
	for i:=0;i<n-1;i++{
		connectNodes(nodesArr[i],nodesArr[i+1])
	}

  //Creating shortcuts
	// for i:=0;i<d;i++{
	// 	//Losowanie dwoch liczb
	// 	pom := n
	// 	a := rand.Intn(pom)
	// 	b := rand.Intn(pom)
  //
	// 	boolVal := false
	// 	for(!boolVal){
	// 		a = rand.Intn(pom)
	// 		for(a==b){
	// 			b = rand.Intn(pom)
	// 			//fmt.Println("los",a,b)
	// 		}
	// 		boolVal = connectNodes(nodesArr[a],nodesArr[b])
	// 	}
	// 	fmt.Println("Stworzono skrot: od ",a," do ",b)
	// }
  connectNodes(nodesArr[0],nodesArr[4])
  //create tables
  pom2 := make(chan int) //licznik true w R_table
  go endListener(pom2,&wg)

	for i:=0;i<n;i++{
    pom := make(chan bool) //print order tylko do debugowania
    go routingTable(nodesArr[i], n, pom, pom2, pschan)
    printOrder = append(printOrder,pom)
  }
  //display connections for all
  fmt.Println("Aktualne polaczenia: ")
  for j:=0;j<len(nodesArr);j++{
    fmt.Print(nodesArr[j].id, ":::  ")
    for i:=0;i<len(nodesArr[j].connections);i++{
  		fmt.Print(nodesArr[j].connections[i].id,", ")
  	}
    fmt.Println("")
  }

  // for i:=0;i<n;i++{
  //   printOrder[i] <- true
  //   time.Sleep(1 * time.Second)
  // }

  //start
  fmt.Println("start")
	for i:=0;i<len(startChanArr);i++{
		startChanArr[i] <- true
	}
  time.Sleep(20 * time.Second)


  // for i:=0;i<n;i++{
  //   printOrder[i] <- true
  //   time.Sleep(1 * time.Second)
  // }
  wg.Wait()
}
