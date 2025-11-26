document.querySelectorAll("span.Func").forEach(funcSpan => {
    const html = funcSpan.innerHTML;

    const updated = html.replace(/\(([^)]*)\)/, (full, args) => {
        const list = args.split(/\s*,\s*/);

        const wrapped = list.map(arg => {
            return arg.replace(
                /(\w+)(\s*:\s*)(\w+)/,    // name : type
                (m, name, colon, type) =>
                    `<span class="FuncArgName">${name}</span>${colon}<span class="FuncArg">${type}</span>`
            );
        });

        return `(${wrapped.join(", ")})`;
    });

    funcSpan.innerHTML = updated;
});
