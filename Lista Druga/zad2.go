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
	ttl int
}

func newPacket(id int,ttl int) *packet {
  packet := packet{id: id}
  packet.visitedNodes = make([]int, 0)
	packet.ttl = ttl
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
  killerChan chan bool
  outcoming []chan *packet
	pastPackets[] int
}

func newNode(id int) *node {
  node := node{id: id}
  node.incoming = make(chan *packet)
	node.killerChan = make(chan bool)
  node.outcoming = make([]chan *packet, 0)
	node.pastPackets = make([]int,0)
  return &node
}

func addOutToNode(node *node,target *node) bool{
	for i:=0;i<len(node.outcoming);i++{
		if(node.outcoming[i]==target.incoming){
			// fmt.Println(node.id,target.id)
			return false
		}
	}
  node.outcoming = append(node.outcoming,target.incoming)
	return true
}

func packetCounter(c chan int,printServer chan string,wg *sync.WaitGroup, lastPacket int){
	nodesInSystem := 0
	noMorePackets := false
	if(wg!=nil){
    defer wg.Done()
  }
	for(!noMorePackets || nodesInSystem!=0){
		// fmt.Println("Packet counter: " , !noMorePackets , " " + strconv.Itoa(nodesInSystem))
		select {
		case increment := <- c:
			if(increment >= 0){ //numer wyslanego pakietu (-1 jesli usuniety ktoryz zostal)
				nodesInSystem = nodesInSystem + 1
			}else{
				nodesInSystem = nodesInSystem - 1
			}
			if(increment == lastPacket){
				noMorePackets = true
			}
		}

		// printServer <- "liczba pakietow w systemie: " + strconv.Itoa(nodesInSystem)
	}
}

func killerThread(printServer chan string,nodesList []*node){
	for{
		time.Sleep(5 * time.Second)
		time.Sleep(time.Duration(rand.Int31n(4)) * time.Second)
		b := rand.Intn(len(nodesList)-2)+1 // in range <1,n-2>
		nodesList[b].killerChan <- true
	}
}

func nodeThread(node *node,printServer chan string, k int, n int, pC chan int){
	trap := false
	test := ""
	// if(wg!=nil){
  //   defer wg.Done()
  // }
  for {
		select {
		case packet := <- node.incoming:
			if(endAll){
				return
			}
			addVisitedToPacket(packet,node.id)
			addVisitedToNode(node,packet.id)
			if(trap){
				test = "Pakiet " + strconv.Itoa(packet.id)  + " wpadl w polapke w wierzcholku " + strconv.Itoa(node.id)
				trap = false //deactivate trap
				pC <- -1 //decrease number of nodes in system
				printServer <- test
			}else{
				if(node.id != n-1){
					test = "Pakiet " + strconv.Itoa(packet.id) + " jest w wierzcholku " + strconv.Itoa(node.id)
				}else{
					test = "Pakiet " + strconv.Itoa(packet.id) + " zostal odebrany"
				}
				test = test + " /ttl:" + strconv.Itoa(packet.ttl)
				printServer <- test
		    // addVisitedToPacket(packet,node.id)
				// addVisitedToNode(node,packet.id)
				packet.ttl = packet.ttl - 1
				if(packet.ttl < 0){
					test = "Pakiet " + strconv.Itoa(packet.id) + " umarl ze starosci w " + strconv.Itoa(node.id)
					pC <- -1 //decrease number of nodes in system
					printServer <- test
				}else{
			    if(node.id == n-1){
						pC <- -1
						if(packet.id==k){
			      	return
						}
			    }
					//Wait
			    time.Sleep(time.Duration(rand.Int31n(2)) * time.Second)
					//Send further
			    if(len(node.outcoming) > 0){
			      whereToSend := rand.Intn(len(node.outcoming))
						//if unable to send, delete packet to stop deadlock
						select {
						case node.outcoming[whereToSend] <- packet:
							//comment line for good looks
						case <-time.After(10 * time.Second):
							pC <- -1 //decrease number of nodes in system
				      printServer <- "Wierzcholek " + strconv.Itoa(node.id) + " nie moze przeslac dalej (TIMEOUT), porzucanie pakietu"
						}

			    }
				}
			}
		case <- node.killerChan:
			trap = true
			test = "Zostawiono polapke w wierzcholku " + strconv.Itoa(node.id)
			printServer <- test
		}//end select
  }
}

var n int = 10 //liczba wierzcholkow
var k int = 1 // liczba pakietow
var d int = 5 //ilosc skrotow
var garbage int = 5 //magic variable
var endAll bool = false

func main() {
	//Var of everything
	n,garbage := strconv.Atoi(os.Args[1]) // liczba wierzcholkow
	d,garbage := strconv.Atoi(os.Args[2]) // liczba skrotow
	b,garbage := strconv.Atoi(os.Args[3]) // liczba 'antyskrotow'
	k,garbage := strconv.Atoi(os.Args[4]) // liczba pakietow
	h,garbage := strconv.Atoi(os.Args[5]) // wartosc ttl pakietow
	if(garbage!=nil){
		fmt.Println("problem occured")
	}
	if(d*3 > n){
		fmt.Println("too much shortcuts")
	}
	if(b*3 > n){
		fmt.Println("too much (anti)shortcuts")
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
		a := newNode(i)
		nodesArr = append(nodesArr,a)
	}
	//Create basic connections
	for i:=0;i<n-1;i++{
		addOutToNode(nodesArr[i],nodesArr[i+1])
	}
	//Creating shortcuts
	for i:=0;i<d;i++{
		//Losowanie dwoch liczb
		pom := n-2
		a := rand.Intn(pom)+1
		b := rand.Intn(pom)+1

		boolVal := false
		for(!boolVal){
			// fmt.Println("___________________________________")
			a = rand.Intn(pom)+1
			// fmt.Println(a==b, a==b-1, b==a-1)
			for(a==b || a==b-1 || b==a-1){
				b = rand.Intn(pom)+1
				// fmt.Println("los",a,b)
				// fmt.Println("Po losie: ",a!=b, a!=b-1, b!=a-1)
			}
			// fmt.Println("potencjal ",a,b)
			if (b < a){
				// fmt.Println("zamiana")
				b = b + a;
				a = b - a;
				b = b - a;
				// fmt.Println("po zamianie ",a,b)
				// fmt.Println("czyli ",nodesArr[a].id,nodesArr[b].id)
			}
			boolVal = addOutToNode(nodesArr[a],nodesArr[b])
		}
		fmt.Println("Stworzono skrot: od ",a," do ",b)
	}
	//Creating (anti)shortcuts
	for i:=0;i<b;i++{
		//Losowanie dwoch liczb
		pom := n-2
		a := rand.Intn(pom)+1
		b := rand.Intn(pom)+1

		boolVal := false
		for(!boolVal){
			// fmt.Println("___________________________________")
			a = rand.Intn(pom)+1
			// fmt.Println(a==b, a==b-1, b==a-1)
			for(a==b){
				b = rand.Intn(pom)+1
				// fmt.Println("los",a,b)
				// fmt.Println("Po losie: ",a!=b, a!=b-1, b!=a-1)
			}
			// fmt.Println("potencjal ",a,b)
			if (a < b){
				// fmt.Println("zamiana")
				b = b + a;
				a = b - a;
				b = b - a;
				// fmt.Println("po zamianie ",a,b)
				// fmt.Println("czyli ",nodesArr[a].id,nodesArr[b].id)
			}
			boolVal = addOutToNode(nodesArr[a],nodesArr[b])
		}
		fmt.Println("Stworzono (anty)skrot: od ",a," do ",b)
	}
	//Packet counter init
	pcChan := make(chan int)
	go packetCounter(pcChan,pom,&wg,k)
	//Killer init
	go killerThread(pom,nodesArr)
	//Start threads
	for i:=0;i<n;i++{
		if(i==n-1){
	  	go nodeThread(nodesArr[i],pom,k,n,pcChan)
		}else{
			go nodeThread(nodesArr[i],pom,k,n,pcChan)
		}
	}
	//Packet sending
  for i:=1; i <= k; i++{
		pom := newPacket(i,h)
		packetsArr = append(packetsArr,pom)
		pcChan <- i
    nodesArr[0].incoming <- pom
    time.Sleep(2 * time.Second)
  }



  wg.Wait()
	fmt.Println("Konczenie symulacji")
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
