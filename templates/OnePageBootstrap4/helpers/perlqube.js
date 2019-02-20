(function ( $ ) {

    var defaults = {
        datatable: {
            dom:    "<'row'<'col-sm-12 col-md-6'l><'col-sm-12 col-md-6'f>>" +
                    "<'row'<'col-sm-12 col-md-5'i><'col-sm-12 col-md-7'p>>" +
                    "<'row'<'col-sm-12'tr>>",
            lengthMenu: [ [10, 25, 50, 100, 500, 1000, -1], [10, 25, 50, 100, 500, 1000, "All"] ],
        },
        template: {
            details: `[% INCLUDE 'helpers/details.html' %]`,
            files: `[% INCLUDE 'helpers/files.html' %]`,
            violations: `[% INCLUDE 'helpers/violations.html' %]`,
            file: `[% INCLUDE 'helpers/file.html' %]`,
            violation: `[% INCLUDE 'helpers/violation.html' %]`,
        },
        data: {
            violations: [],
        },
    };

    Handlebars.registerHelper('severitytostr', function(severity) {
        const level = [ 'info', 'minor', 'major', 'critical', 'blocker' ];
        return level[severity - 1];
    });

    Handlebars.registerHelper('policy-link', function(policy) {
        return new Handlebars.SafeString(getPolicyLink(policy));
    });

    Handlebars.registerHelper('policy-short', function(policy) {
        return getPolicyShort(policy);
    });

    Handlebars.registerHelper('inheritance-children', function(tree) {
        return new Handlebars.SafeString(inheritanceChild(tree));
    });

    Handlebars.registerHelper('podtohtml', function(pod) {
        var html = '',
            inScript = false,
            inParagraph = false;

        pod.replace(/^[ ]{0,4}([^ ])/mg, '$1').split('\n').forEach(row => {
            const regexScript = /^[ ]{6}/;
            var text = '';

            if ( row.match(regexScript) ) {
                if (!inScript) {
                    if (!inParagraph) {
                        html += '</p>';
                    }

                    html += '<pre><code class="perl">';
                    inScript = true;
                }

                // sanitize
                text = $('<div />').text(row.replace(regexScript, '')).html();
            }
            else if ( row ) {
                if (inScript) {
                    html += '</code></pre>';
                }

                if (!inParagraph) {
                    html += '<p>'
                }

                inParagraph = true;

                // sanitize
                text = $('<div />').text(row).html()
                .replace(/`'([^']+)''/g, '<code>$1</code>')
                .replace(/`([^']+)'/g, '<code>$1</code>');
            }
            else if (!inScript) {
                html += inParagraph ? '</p>' : '<p>';
                inParagraph = inParagraph ? false : true;
            }

            html += text + '\n';
        });

        if ( inScript ) {
            html += '</code></pre>';
        }
        if ( inParagraph ) {
            html += '</p>';
        }

        return new Handlebars.SafeString( html );
    });

    $.fn.initCollapse = function() {
        return $(this).each(function() {
            $('.collapsible', this).on('click', function() {
                var target = $('> .collapse', $(this).parent());
                var icon = $('i.collapse-icon', this);

                target.collapse( target.is('.show') ? 'hide' : 'show');
                icon.text( icon.text() === 'keyboard_arrow_up' ? 'keyboard_arrow_down' : 'keyboard_arrow_up');
            });
        });
    };

    $.fn.initPerlqubeLink = function() {
        return $(this).each(function() {
            $('.perlqube-link-file', this).each(function() {
                $(this).wrapInner('<a href="#" />').on('click', e => {
                    e.preventDefault();
                    $(this).closest('.perlqube').PerlQube('showFile', $(this).text());
                });
            });
        });
    };

    $.fn.PerlQube = function( methodOrOptions ) {

        var args = arguments;

        var name = 'PerlQube';

        var PerlQube = function(el, options) {
            return this._init(el, options);
        };

        PerlQube.prototype = {
            _init: function(el, options) {
                console.log(options.data); // TODO to remove
                this.element = $(el);
                this.options = options;

                this.element.addClass('perlqube');

                this.wrapper = {};
                this.wrapper.details = $('<div />').appendTo(this.element);
                this.wrapper.files = $('<div />').appendTo(this.element);
                this.wrapper.violations = $('<div />').appendTo(this.element);

                if ( this.options.data.metrics ) {
                    this.showDetails();
                    this.showFiles();
                }

                this.showViolations();

                return this;
            },

            showDetails: function() {
                var template = Handlebars.compile(this.options.template.details);
                var html = template({
                    files: this.options.data.metrics.sub_count,
                    packages:  this.options.data.metrics.package_count,
                    methods:  this.options.data.metrics.sub_count,
                    lines:  this.options.data.metrics.lines,
                    violations:  this.options.data.violations.length,
                    complexity:  this.options.data.metrics.main_stats.mccabe_complexity,
                });

                $( this.wrapper.details ).html(html).initCollapse();
            },

            showFiles: function() {
                var self = this;
                var template = Handlebars.compile(this.options.template.files);

                $( this.wrapper.files ).html( template() ).initCollapse();

                $('table', this.wrapper.files).DataTable({
                    dom: this.options.datatable.dom,
                    lengthMenu: this.options.datatable.lengthMenu,
                    data: this.options.data.metrics.file_stats,
                    columns: [{
                        title: 'Path',
                        data: function( row ) {
                            return row.path.replace(/^[.][\\/]/, '');
                        },
                        createdCell: function(td, cellData) {
                            $(td).wrapInner(
                                $('<a href="#" />').on('click', e => {
                                    e.preventDefault();
                                    self.showFile(cellData);
                                })
                            );
                        },
                    }, {
                        title: 'Violations',
                        className: 'text-center',
                        searchable: false,
                        data: function( row ) {
                            var path = row.path.replace(/^[.][\\/]/, '');

                            return self.options.data.violations.filter(violation => violation.filename === path).length;
                        },
                    }, {
                        title: 'Methods',
                        className: 'text-center',
                        searchable: false,
                        data: function( row ) {
                            return row.subs.length;
                        },
                    }, {
                        title: 'Lines',
                        data: 'lines',
                        className: 'text-center',
                        searchable: false,
                    }, {
                        title: 'Complexity',
                        data: 'mccabe_complexity',
                        className: 'text-center',
                        searchable: false,
                    }, {
                        title: 'Complexity total',
                        className: 'text-center',
                        searchable: false,
                        data: function( row ) {
                            var complexity = row.mccabe_complexity;

                            if ( Array.isArray( row.subs ) ) {
                                row.subs.forEach(sub => complexity += sub.mccabe_complexity);
                            }

                            return complexity;
                        },
                    }, {
                        title: '',
                        data: 'path',
                        searchable: false,
                        orderable: false,
                        className: 'text-center',
                        render: function() {
                            return '<button class="btn btn-link"><i class="material-icons">launch</i></button>'
                        },
                        createdCell: function(td, cellData) {
                            $('button', td).on('click', e => {
                                e.preventDefault();
                                self.showFile(cellData.replace(/^[.][\\/]/, ''));
                            });
                        },
                    }],
                });
            },

            showViolations: function() {
                var self = this;
                var template = Handlebars.compile(this.options.template.violations);

                $( this.wrapper.violations ).html( template() ).initCollapse();

                $('table', this.wrapper.violations).DataTable({
                    dom: this.options.datatable.dom,
                    lengthMenu: this.options.datatable.lengthMenu,
                    data: this.options.data.violations,
                    columns: [{
                        title: 'Path',
                        data: 'filename',
                        createdCell: function(td, cellData) {
                            if ( self.options.data.metrics ) {
                                $(td).wrapInner(
                                    $('<a href="#" />').on('click', e => {
                                        e.preventDefault();
                                        self.showFile(cellData);
                                    })
                                );
                            }
                        },
                    }, {
                        title: 'Line',
                        data: 'line',
                        className: 'text-center',
                        searchable: false,
                    }, {
                        title: 'Policy',
                        data: 'policy',
                        render: function(data) {
                            return getPolicyLink(data);
                        },
                    }, {
                        title: 'Severity',
                        data: 'severity',
                        className: 'text-center',
                        searchable: false,
                    }, {
                        title: 'Description',
                        data: 'description',
                    }, {
                        title: '',
                        data: 'filename',
                        searchable: false,
                        orderable: false,
                        className: 'text-center',
                        render: function() {
                            return '<button class="btn btn-link"><i class="material-icons">launch</i></button>'
                        },
                        createdCell: function(td, cellData, rowData) {
                            $('button', td).on('click', e => {
                                e.preventDefault();
                                self.showViolation(rowData);
                            });
                        },
                    }],
                });
            },

            showViolation: function(violation) {
                $('.modal', this.element).modal('hide').remove();

                var template = Handlebars.compile(this.options.template.violation);
                var html = template(violation);

                $(html).appendTo( this.element )
                .modal()
                .on('hidden.bs.modal', function() {
                    $(this).remove();
                    // hack
                    $('.modal-backdrop').remove();
                })
                .initCollapse()
                .initPerlqubeLink()
                .find('pre code').each(function(i, block) {
                    hljs.highlightBlock(block);
                });
            },

            showFile: function(filename) {
                var self = this;
                $('.modal', this.element).modal('hide').remove();

                var data = {
                    filename: filename,
                    violations: this.options.data.violations
                        .filter(violation => violation.filename === filename)
                        .sort( (a, b) => b.severity - a.severity  ),
                    metrics: this.options.data.metrics.file_stats
                        .find(metric => metric.path.replace(/^\../, '') === filename),
                    analyzer: this.options.data.analyzer[filename],
                };
                var template = Handlebars.compile(this.options.template.file);
                var html = template(data);
                var self = this;

                var node = $(html).appendTo( this.element )
                .modal()
                .on('hidden.bs.modal', function() {
                    $(this).remove();
                    // hack
                    $('.modal-backdrop').remove();
                })
                .on('shown.bs.modal', function() {
                    $('pre code', node).each(function(i, block) {
                        hljs.highlightBlock(block);
                    });

                    $('table.perlqube-file-subs', node).DataTable({
                        dom: self.options.datatable.dom,
                        lengthMenu: self.options.datatable.lengthMenu,
                        data: data.metrics.subs,
                        columns: [{
                            title: 'Name',
                            data: 'name',
                        }, {
                            title: 'Lines',
                            className: 'text-center',
                            searchable: false,
                            data: 'lines',
                        }, {
                            title: 'Complexity',
                            className: 'text-center',
                            searchable: false,
                            data: 'mccabe_complexity',
                        }]
                    });

                    $('.inheritance-tree', node).each(function() {
                        const width = 960;

                        function tree(d) {
                            const root = d3.hierarchy(d);

                            root.dx = 10;
                            root.dy = width / (root.height + 1);

                            return d3.tree().nodeSize([root.dx, root.dy])(root);
                        }

                        const treeData = getInheritanceTree(data);
                        const root = tree(treeData);
                        let x0 = Infinity;
                        let x1 = -x0;

                        root.each(d => {
                            if (d.x > x1) x1 = d.x;
                            if (d.x < x0) x0 = d.x;
                        });

                        /*const svg = d3.select(DOM.svg(width, x1 - x0 + root.dx * 2))
                            .style("width", "100%")
                            .style("height", "auto");
                        */
                        $(this).height( x1 - x0 + root.dx * 2 );
                        const svg = d3.select( this )
                            .append("svg")
                            .attr("width", "100%")
                            .attr("height", "auto");

                        const g = svg.append("g")
                            //.attr("font-family", "sans-serif")
                            //.attr("font-size", 10)
                            .attr("transform", `translate(${root.dy / 3},${root.dx - x0 + 150})`);

                        const link = g.append("g")
                          .attr("fill", "none")
                          .attr("stroke", "#555")
                          .attr("stroke-opacity", 0.4)
                          .attr("stroke-width", 1.5)
                        .selectAll("path")
                          .data(root.links())
                          .enter().append("path")
                            .attr("d", d3.linkHorizontal()
                                .x(d => d.y)
                                .y(d => d.x));

                        const node = g.append("g")
                            .attr("stroke-linejoin", "round")
                            .attr("stroke-width", 5)
                          .selectAll("g")
                          .data(root.descendants().reverse())
                          .enter().append("g")
                            .attr("transform", d => `translate(${d.y},${d.x})`);

                        node.append("circle")
                            .attr("fill", d => d.children ? "#555" : "#999")
                            .attr("r", 5);

                        node.append("text")
                            .attr("dy", "1em")
                            .attr("x", d => d.children ? d.y / 2 : 6)
                            .attr("text-anchor", d => d.children ? "end" : "start")
                            .text(d => d.data.name);

                        $( svg.node() ).appendTo(this);

                        /*
                        const root = d3.hierarchy(getInheritanceTree(data));

                        const height =  300

                        const svg = d3.select( this )
                            .append("svg")
                            .attr("width", "100%")
                            .attr("height", height)
                            style("user-select", "none");

                        const gLink = svg.append("g")
                            .attr("fill", "none")
                            .attr("stroke", "#555")
                            .attr("stroke-opacity", 0.4)
                            .attr("stroke-width", 1.5);

                        const gNode = svg.append("g")
                            .attr("cursor", "pointer");

                        const duration = d3.event && d3.event.altKey ? 2500 : 250;
                        const nodes = root.descendants().reverse();
                        const links = root.links();

                        tree(root);
                        */

                        console.log(root);

                    });
                })
                .initCollapse();
            }
        };

        return $(this).each(function() {
            var instance = $.data( this, name );

            if ( typeof instance === 'undefined' ) {
                if ( typeof methodOrOptions === 'object' || ! methodOrOptions ) {
                    settings = $.extend( true, {}, defaults, methodOrOptions );
                    return $.data( this, name, new PerlQube(this, settings) );
                }

                $.error('PerlQube not initialized.')
            }
            else {
                if ( typeof methodOrOptions !== 'object' ) {
                    return instance[ methodOrOptions ].apply( instance, Array.prototype.slice.call( args, 1 ) );
                }

                $.error('PerlQube already initialized.')
            }
        });

    };

    $.fn.PerlQube.defaults = defaults;

    function getPolicyShort(policy) {
        return policy.replace(/Perl::Critic::Policy::/, '');
    }

    function getPolicyLink(policy) {
        return '<a href="https://metacpan.org/pod/' + policy + '" target="_blank">' + getPolicyShort(policy) + '</a>';
    }

    function inheritanceChild (tree) {
        var html = '';

        tree
        .filter(child => child.type !== 'dependency')
        .sort( (a, b) => a.name !== b.name ? a.name < b.name ? -1 : 1 : 0  )
        .forEach(child => {
            var isParent = child.children && child.children.length;
            const className = isParent ? 'collapsible' : '';

            html += '<li class="' + [ child.type, 'list-group-item'].join(' ') + '">';

            html += '<h5 class="' + className + '">';

            if (isParent) {
                html += '<i class="material-icons collapse-icon">keyboard_arrow_down</i>';
            }

            html += child.name + '</h5>';

            if ( isParent ) {
                html += '<ul class="collapse">';
                html += inheritanceChild( child.children );
                html += '</ul>';
            }

            html += '</li>';
        });

        return html;
    }

    function getInheritanceTree(data) {
        function addParentToTree(node, parent) {
            var nodeData = {
                name: node.name,
                children: [],
            };

            parent.children.push(nodeData);

            node.parents.forEach(supParent => addParentToTree(supParent, nodeData));
        }

        var tree = {
            name: data.analyzer.tree.name,
            children: [],
        };

        data.analyzer.tree.parents.forEach(parent => addParentToTree(parent, tree));

        return tree;
    }

})( jQuery );
