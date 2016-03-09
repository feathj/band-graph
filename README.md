# Radiohead is a good starting point
http://graph.docker/index?base_ref=Radiohead&max_recursion=10

# Call me a hole
http://graph.docker/index?base_ref=Nine_Inch_Nails&max_recursion=8
http://graph.docker/index?base_ref=Carly_Rae_Jepsen&max_recursion=8

# April Ludgate-Dwyer
http://graph.docker/index?base_ref=Neutral_Milk_Hotel&max_recursion=8
http://graph.docker/index?base_ref=Dave_Matthews_Band&max_recursion=8


# Genre with most bands
```
MATCH (b:band)-[r]->(g:genre)
RETURN g, COUNT(r)
ORDER BY COUNT(r) DESC
LIMIT 10
```

# Band with most associated acts
```
MATCH (b:band)-[r:associated]->(rb)
RETURN b, COUNT(r)
ORDER BY COUNT(r) DESC
LIMIT 20
```

# Relationships between bands
```
MATCH (a:band {name: "Nine Inch Nails"}), (b:band {name: "Carly Rae Jepsen"}),
p = shortestPath((a)-[:associated*]-(b))
RETURN p
```
Dave Matthews Band -> Neutral Milk Hotel
Nine Inch Nails -> Carly Rae Jepsen
LMFAO -> Frank Sinatra
