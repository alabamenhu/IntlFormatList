# IntlFormatList
 A module for formatting lists in a localized manner

To format lists using this module, use the provided sub C<format-list>:

    format-list @list

There are three named options available:

  * **`:language`** (may be abbreviated to **`:lang`**)  
The language to use for formatting.
Should be a valid BCP-47 language code.
Defaults to whatever value `Intl::UserLanguage`'s `user-language` returns (which defaults to 'en' if undetectable).
  * **`:type`**  
There are three types possible: *and*, *or*, *unit*.
The *and* type indicates a list of collective values (e.g. 'apples, oranges, and peaches').
The *or* type indicates a list of alternate values (e.g. 'apples, oranges, or peaches').
The *unit* type indicates a list of values, without specifying any relation between them (e.g. 'apples, oranges, peaches').
Defaults to *and*.

  * **`:length`**  
There are three lengths possible: *standard*, *short*, *narrow*.
Many languages do not distinguish *standard* and *short*, perhaps only omitting spaces if they do.
In contrast, *narrow* is designed for minimal contexts, but may be ambiguous between the forms and should have additional context provided if used.
Defaults to *standard*.

## Examples

If your language is set to English…

    my @list = <apples oranges bananas>;
    say format-list @list;              # 'apples, oranges, and bananas'
    say format-list @list, :type<or>;   # 'apples, oranges, or bananas'
    say format-list @list, :type<unit>; # 'apples, oranges, bananas'

But if your language is set to Spanish…

    my $a = 'manzanas';
    my $o = 'naranjas';
    my $b = 'plátanos';
    say format-list $a, $o, $b;            # 'manzanas, naranjas y plátanos'
    say format-list $a, $o, $b, :type<or>; # 'manzanas, naranjas o plátanos'
    say format-list $a, $o, $b, :type<unit; # 'manzanas, naranjas y plátanos'

As you can tell, the `format-list` sub follows the single-argument rule, allowing either a list proper *or* an inline list of items.
All items passed in are stringified.

## Version history

  * **v0.5**  
    * First release as its own module
    * Much cleaner / more maintainable codebase
  * **v0.1** – **v0.4.3**
    * Initial release as a part of the `Intl::CLDR` module
    * No changes made after initial release

## License and Copyright

© 2020 Matthew Stephen Stuckwisch.  Licensed under Artistic License 2.0