package main

import (
	"fmt"
  "math/rand"
  "sync"
  "time"
  "strconv"
  "os"
)

func printServer(output chan string){
	for{
		str := <- output
		fmt.Println(str)
	}
}

type packet struct{
  id int
  visitedNodes[] int
}

func newPacket(id int) *packet {
  packet := packet{id: id}
  packet.visitedNodes = make([]int, 0)
  return &packet
}

func addVisitedToPacket(packet *packet,nodeId int){
  packet.visitedNodes = append(packet.visitedNodes,nodeId)
}
func addVisitedToNode(node *node,packetId int){
  node.pastPackets = append(node.pastPackets,packetId)
}

type node struct{
  id int
  incoming chan *packet
  outcoming []chan *packet
	pastPackets[] int
  lastNode bool
}

func newNode(id int, lastNode bool) *node {
  node := node{id: id}
  node.lastNode = lastNode
  node.incoming = make(chan *packet)
  node.outcoming = make([]chan *packet, 0)
	node.pastPackets = make([]int,0)
  return &node
}

func addOutToNode(node *node,target *node){
  node.outcoming = append(node.outcoming,target.incoming)
}

func nodeThread(node *node,printServer chan string, wg *sync.WaitGroup){
  if(wg!=nil){
    defer wg.Done()
  }
  for {
    packet := <- node.incoming
		if(endAll){
			return
		}
		test := ""
		if(!node.lastNode){
			test = "Pakiet " + strconv.Itoa(packet.id) + " jest w wierzcholku " + strconv.Itoa(node.id)
		}else{
			test = "Pakiet " + strconv.Itoa(packet.id) + " zostal odebrany"
		}
		printServer <- test
    addVisitedToPacket(packet,node.id)
		addVisitedToNode(node,packet.id)

    if(node.lastNode && packet.id==k){
      return
    }
		//Wait
    time.Sleep(time.Duration(rand.Int31n(2)) * time.Second)
		//Send further
    if(len(node.outcoming) > 0){
      whereToSend := rand.Intn(len(node.outcoming))
      node.outcoming[whereToSend] <- packet
    }
  }
}

var k int = 1 // liczba pakietow
var n int = 10 //liczba wierzcholkow
var d int = 5 //ilosc skrotow
var garbage int = 5 //ilosc skrotow
var endAll bool = false

func main() {
	//Var of everything
	k,garbage := strconv.Atoi(os.Args[1])
	n,garbage := strconv.Atoi(os.Args[2])
	d,garbage := strconv.Atoi(os.Args[3])
	if(garbage!=nil){
		fmt.Println("problem occured")
	}
	//Nodes
	nodesArr := make([]*node,0)
	//Packets
	packetsArr := make([]*packet,0)
	//Print server init
	pom := make(chan string)
	go printServer(pom)

	//END Print server init
	//Random seed
  rand.Seed(time.Now().UTC().UnixNano())
	//Wait group
  var wg sync.WaitGroup
  wg.Add(1)

	//Create Basic nodes
	for i:=0;i<n;i++{
		a := newNode(i,i==n-1)
		nodesArr = append(nodesArr,a)
	}
	//Create basic connections
	for i:=0;i<n-1;i++{
		addOutToNode(nodesArr[i],nodesArr[i+1])
	}
	//Creating shortcuts
	for i:=0;i<d;i++{
		//Losowanie dwoch liczb
		pom1 := n-2
		a := rand.Intn(pom1)
		pom := n-2-a
		b := rand.Intn(pom)+1
		b = b+a
		addOutToNode(nodesArr[a],nodesArr[b])
		fmt.Println("Stworzono skrot: od ",a," do ",b)
	}
	//Start threads
	for i:=0;i<n;i++{
		if(i==n-1){
	  	go nodeThread(nodesArr[i],pom,&wg)
		}else{
			go nodeThread(nodesArr[i],pom,nil)
		}
	}
	//Packet sending
  for i:=1; i <= k; i++{
		pom := newPacket(i)
		packetsArr = append(packetsArr,pom)
    nodesArr[0].incoming <- pom
    time.Sleep(1 * time.Second)
  }



  wg.Wait()
	time.Sleep(1 * time.Second)
	fmt.Println("Statystyki")
	endAll = true
	fmt.Println("Wierzcholek i lista pakietow ktore obsluzyl:")
	for i:=0; i < len(nodesArr); i++{
		fmt.Println(nodesArr[i].id,nodesArr[i].pastPackets)
	}
	fmt.Println("Podroz poszczegolnych pakietow przez wierzcholki:")
	for i:=0; i < len(packetsArr); i++{
		fmt.Println(packetsArr[i].id,packetsArr[i].visitedNodes)
	}
}
