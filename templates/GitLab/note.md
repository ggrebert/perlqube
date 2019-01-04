[% violation.description %]
---------------------------

Severity: __[% self.severity_to_str( violation.severity ) %]__

Policy: [[% violation.policy %]](https://metacpan.org/pod/[% violation.policy %])

File: [[% violation.filename %] L[% violation.line_number %]](/../blob/[% self.config.git.ref %]/[% violation.filename %]#L[% violation.line_number %])

<details>
<summary>Click me to show diagnostic</summary>

---

[% self.str_to_markdown( violation.diagnostics ) %]

</details>
