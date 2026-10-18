# 8 Conclusion, limitations and future work

> **PLACEHOLDER-NOT-YET-DELIVERED (all members, written together after Sections 5-7 are final)**
>
> Points already known to go into *limitations*:
> - Serial times include the O(n) initialisation and queue allocation of `bfs_serial`; GPU times exclude
>   allocation, the levels initialisation and the final copy-back (playbook 6.3). This is a small bias in
>   favour of the GPU speedups.
> - TEPS counts CSR entries (both directions of each undirected edge); Graph500 counts half of this.
> - One GPU model only; medians of 5 sources x 5 trials.
> - Directed inputs (soc-LiveJournal1) are symmetrised, so we traverse the undirected version.
>
> Future work candidates: direction-optimising BFS (Beamer et al.), splitting very large adjacency lists across
> several blocks, skipping classification for tiny frontiers.
