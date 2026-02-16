# Rivermax Receive Test Commands

Run on render-05 (10.0.0.5) to verify nDisplay 2110 streams from content nodes.

## Node 1 (225.0.0.1)

```
& "C:\Program Files\Mellanox\Rivermax\apps\media_receiver\media_receiver.exe" -i 10.0.0.5 -m 225.0.0.1 -p 50000 --pixel-format RGB_10
```

## Node 2 (225.0.0.2)

```
& "C:\Program Files\Mellanox\Rivermax\apps\media_receiver\media_receiver.exe" -i 10.0.0.5 -m 225.0.0.2 -p 50000 --pixel-format RGB_10
```

## Node 3 (225.0.0.3)

```
& "C:\Program Files\Mellanox\Rivermax\apps\media_receiver\media_receiver.exe" -i 10.0.0.5 -m 225.0.0.3 -p 50000 --pixel-format RGB_10
```

## Node 4 (225.0.0.4)

```
& "C:\Program Files\Mellanox\Rivermax\apps\media_receiver\media_receiver.exe" -i 10.0.0.5 -m 225.0.0.4 -p 50000 --pixel-format RGB_10
```
