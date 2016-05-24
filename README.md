# ATOM Plugin - web-accessibility-checker package

The plugin provides instant feedback whether written HTML code conforms to following defined rules or not. The user can enable and disable the continuous issue checking and check the whole page on command. These features can be used via key combinations or via the ATOM menu Packages / Web Accessibility Checker. The defined rules have been selected because they can easily be checked without knowlegde of the complete website, JS files and CSS files. **The plugin has still some small bugs, but it is stable and the core functionality is working. (in all tested conditions till now)**

## Rules
### Img alternative
**WCAG 2.0 chapter:** 1.1.1
**Rule:** ```Each <img> tag should have an alt attribute.```

### Label
**WCAG 2.0 chapter:** 3.3.2
**Rule:** ```Each <input> tag should have a <label> tag, where the for attribute match the id attribute of the <input> tag OR the <label> tag covers the <input> tag and the description.```

### Page title
**WCAG 2.0 chapter:** 2.4.2
**Rule:** ```A <head> section should include a <title> element.```

### Language
**WCAG 2.0 chapter:** 3.1.1
**Rule:** ```The lang attribute should be defined in the <html> tag.```

### Link
**WCAG 2.0 chapter:** 2.4.9
**Rule:** ```<a> tags should only include a title attribute if it is not possible to make the link destination clear with the link text alone.```

## More information
The algorithms are mainly based on regExp. The testing of those was done through code samples with the consequences that the amount and diversity of those are an important factor for the quality of the results. Till now the algorithms work quite good and fast enough to provide a instant feedback feeling (about 50ms execution time). To ensure that the typing experience will not get influenced, the package will check the page 300ms after the user stopped typing.
In case of interest, I could invest more time to fix the known issues or if you want to further develop the plugin, feel free to contact me.

## Known Bugs
**Tooltips:** If the user scrolls the highlighted code section and therefore also the element which displays onMouseOver a tooltip with extra information, out of the visible area of the current editor, the tooltip is not working anymore.

![alt text](https://raw.githubusercontent.com/web-weber/web-accessibility-checker/master/web-accessibility-checker.gif "Example image of instance feedback")
