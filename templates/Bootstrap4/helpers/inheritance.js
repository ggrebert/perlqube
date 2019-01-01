[% USE JSON %]

const treeData = [% analyzer.tree.json %];

var nodes = [{
    name: treeData.name,
    type: treeData.type,
}];
var links = [];

const height = nodes.length * 500;

treeData.children.forEach(element => initChildren(element, treeData.name));
treeData.parents.forEach(element => initParents(element, treeData.name));

const svg = d3.select("#inheritance-tree")
    .append("svg")
    .attr("width", "100%")
    .attr("height", height);

const link = svg.append("g")
    .attr("stroke-opacity", 0.6)
    .selectAll("line")
    .data(links)
    .enter().append("line")
    .attr("stroke-width", 3)
    .attr("class", d => "line line-" + d.type);

const node = svg.append("g")
    .selectAll("ellipse")
    .data(nodes)
    .enter().append("ellipse")
    .attr("class", d => "node node-" + d.type)
    .attr("rx", d => d.name.length * 6)
    .attr("ry", d => 25 + 3 * Math.round(d.name.length / 25) )
    .on('mouseover', d => {
        link.filter(e => {
            return e.target.id == d.name || e.source.id == d.name
        })
        .classed('highlight', true)
    })
    .on('mouseout', d => link.classed('highlight', false))
    .call(
        d3.drag()
        .on("start", dragstarted)
        .on("drag", dragged)
        .on("end", dragended)
    );

const text = svg.append("g")
    .selectAll("text")
    .data(nodes)
    .enter().append("text")
    .attr("class", d => "label label-" + d.type)
    .attr("dy", 2)
    .attr("text-anchor", "middle")
    .text(d => d.name)
    .on('mouseover', d => {
        link.filter(e => {
            return e.target.id == d.name || e.source.id == d.name
        })
        .classed('highlight', true)
    })
    .on('mouseout', d => link.classed('highlight', false));

const simulation = d3.forceSimulation(nodes)
    .force("link", d3.forceLink(links).id(d => d.name).strength(0))
    .force("charge", d3.forceManyBody())
    .force("center", d3.forceCenter(svg.node().getBoundingClientRect().width / 2, height / 2))
    .on("tick", () => {
        const minX = 25;
        const maxY = height - minX / 2;
        const maxX = svg.node().getBoundingClientRect().width - minX;
        link
            .attr("x1", d => d.source.x)
            .attr("y1", d => d.source.y)
            .attr("x2", d => d.target.x)
            .attr("y2", d => d.target.y);

        node
            .attr("cx", d => d.x < minX ? minX : ( d.x > maxX ? maxX : d.x ))
            .attr("cy", d => d.y < minX ? minX : ( d.y > maxY ? maxY : d.y ));

        text
            .attr("x", d => d.x < minX ? minX : ( d.x > maxX ? maxX : d.x ))
            .attr("y", d => d.y < minX ? minX : ( d.y > maxY ? maxY : d.y ));
    });

function dragstarted(d) {
    if (!d3.event.active)
        simulation.alphaTarget(0.3).restart();

    d.fx = d.x;
    d.fy = d.y;
}

function dragged(d) {
    d.fx = d3.event.x;
    d.fy = d3.event.y;
}

function dragended(d) {
    if (!d3.event.active)
        simulation.alphaTarget(0);

    d.fx = null;
    d.fy = null;
}

function appendToNodes(element) {
    var found = nodes.find(function(el) {
        return element.name === el.name;
    });

    if (!found) {
        nodes.push({
            name: element.name,
            id: element.name,
            type: element.type,
        });
    }
};

function initChildren(element, source) {
    appendToNodes(element);

    links.push({
        source: source,
        target: element.name,
        type: element.type,
    });

    if (element.children) {
        element.children.forEach(child => initChildren(child, element.name));
    }
};

function initParents(element, target) {
    appendToNodes(element);

    links.push({
        source: element.name,
        target: target,
        type: element.type,
    });

    if (element.children) {
        element.children.forEach(child => initChildren(child, element.name));
    }

    if (element.parents) {
        element.parents.forEach(parent => initParents(parent, element.name));
    }
};
