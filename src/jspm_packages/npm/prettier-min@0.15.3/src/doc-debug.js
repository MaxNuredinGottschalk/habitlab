"use strict";function flattenDoc(a){if("concat"===a.type){for(var b=[],c=0;c<a.parts.length;++c){const d=a.parts[c];if("string"!=typeof d&&"concat"===d.type)[].push.apply(b,flattenDoc(d).parts);else{const e=flattenDoc(d);""!==e&&b.push(e)}}return Object.assign({},a,{parts:b})}return"if-break"===a.type?Object.assign({},a,{breakContents:null==a.breakContents?null:flattenDoc(a.breakContents),flatContents:null==a.flatContents?null:flattenDoc(a.flatContents)}):"group"===a.type?Object.assign({},a,{contents:flattenDoc(a.contents),expandedStates:a.expandedStates?a.expandedStates.map(flattenDoc):a.expandedStates}):a.contents?Object.assign({},a,{contents:flattenDoc(a.contents)}):a}function printDoc(a){return"string"==typeof a?JSON.stringify(a):"line"===a.type?a.literalline?"literalline":a.hard?"hardline":a.soft?"softline":"line":"break-parent"===a.type?"breakParent":"concat"===a.type?"["+a.parts.map(printDoc).join(", ")+"]":"indent"===a.type?"indent("+a.n+", "+printDoc(a.contents)+")":"if-break"===a.type?"ifBreak("+printDoc(a.breakContents)+(a.flatContents?", "+printDoc(a.flatContents):"")+")":"group"===a.type?a.expandedStates?"conditionalGroup(["+a.expandedStates.map(printDoc).join(",")+"])":(a.break?"wrappedGroup":"group")+"("+printDoc(a.contents)+")":void 0}module.exports={printDocToDebug:function(a){return printDoc(flattenDoc(a))}};
