# react-native-css/types against React Native 0.88

`index.ts` loads `react-native-css/types` and sets the `className` props it adds; `control.ts` loads `react-native`
alone. `check.sh` installs, type-checks both with `skipLibCheck: false`, and prints the errors only the first program
has.

```sh
bash check.sh
```

It exits 1 while loading `react-native-css/types` adds an error, 0 once it adds none and `index.ts` type-checks, and 2
when a step fails.
