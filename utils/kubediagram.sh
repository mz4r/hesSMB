#!/bin/bash
KUBECONFIG_FILE="../kubeconfig_cluster"
OUTPUT_DIR="diagrams_output"
DIAGRAM_TOOL="kube-diagrams"

mkdir -p "$OUTPUT_DIR"

echo "Génération du diagramme global (tous les namespaces)..."
kubectl --kubeconfig "$KUBECONFIG_FILE" get all --all-namespaces -o yaml | $DIAGRAM_TOOL -o "$OUTPUT_DIR/all-cluster.png" -

echo "🔍 Récupération de la liste des namespaces..."
NAMESPACES=$(kubectl --kubeconfig "$KUBECONFIG_FILE" get ns -o jsonpath='{.items[*].metadata.name}')

for ns in $NAMESPACES
do
    echo "🎨 Traitement du namespace : $ns"
    kubectl --kubeconfig "$KUBECONFIG_FILE" get all -n "$ns" -o yaml 2>/dev/null | \
    $DIAGRAM_TOOL -o "$OUTPUT_DIR/namespace-$ns.png" -
    
    if [ $? -eq 0 ]; then
        echo "OK : $OUTPUT_DIR/namespace-$ns.png"
    else
        echo "KO : $OUTPUT_DIR/namespace-$ns.png"
    fi
done

echo "🎉 Terminé ! go dans $OUTPUT_DIR/"