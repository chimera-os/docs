# `Tutorial: Write a Shell in C` - Stephen Brennan - 16 January 2015

*Retrieved from [Stephen Brennan's blog](https://brennan.io/2015/01/16/write-a-shell-in-c/). The code is hosted on [GitHub](https://github.com/brenns10/lsh).*

## Introduction

It’s easy to view yourself as “not a real programmer.” There are programs out there that everyone uses, and it’s easy to put their developers on a pedestal. Although developing large software projects isn’t easy, many times the basic idea of that software is quite simple. Implementing it yourself is a fun way to show that you have what it takes to be a real programmer. So, this is a walkthrough on how I wrote my own simplistic Unix shell in C, in the hopes that it makes other people feel that way too.

The code for the shell described here, dubbed lsh, is available on GitHub.

University students beware! Many classes have assignments that ask you to write a shell, and some faculty are aware of this tutorial and code. If you’re a student in such a class, you shouldn’t copy (or copy then modify) this code without permission. And even then, I would advise against heavily relying on this tutorial.
Basic lifetime of a shell

Let’s look at a shell from the top down. A shell does three main things in its lifetime.

- **Initialize:** In this step, a typical shell would read and execute its configuration files. These change aspects of the shell’s behavior.
- **Interpret:** Next, the shell reads commands from stdin (which could be interactive, or a file) and executes them.
- **Terminate:** After its commands are executed, the shell executes any shutdown commands, frees up any memory, and terminates.

These steps are so general that they could apply to many programs, but we’re going to use them for the basis for our shell. Our shell will be so simple that there won’t be any configuration files, and there won’t be any shutdown command. So, we’ll just call the looping function and then terminate. But in terms of architecture, it’s important to keep in mind that the lifetime of the program is more than just looping.

```c
int main(int argc, char **argv)
{
  // Load config files, if any.

  // Run command loop.
  lsh_loop();

  // Perform any shutdown/cleanup.

  return EXIT_SUCCESS;
}
```

Here you can see that I just came up with a function, `lsh_loop()`, that will loop, interpreting commands. We’ll see the implementation of that next.

## Basic loop of a shell

So we’ve taken care of how the program should start up. Now, for the basic program logic: what does the shell do during its loop? Well, a simple way to handle commands is with three steps:

- **Read:** Read the command from standard input.
- **Parse:** Separate the command string into a program and arguments.
- **Execute:** Run the parsed command.

Here, I’ll translate those ideas into code for `lsh_loop()`:

```c
void lsh_loop(void)
{
  char *line;
  char **args;
  int status;

  do {
    printf("> ");
    line = lsh_read_line();
    args = lsh_split_line(line);
    status = lsh_execute(args);

    free(line);
    free(args);
  } while (status);
}
```

Let’s walk through the code. The first few lines are just declarations. The do-while loop is more convenient for checking the status variable, because it executes once before checking its value. Within the loop, we print a prompt, call a function to read a line, call a function to split the line into args, and execute the args. Finally, we free the line and arguments that we created earlier. Note that we’re using a status variable returned by `lsh_execute()` to determine when to exit.

## Reading a line

Reading a line from stdin sounds so simple, but in C it can be a hassle. The sad thing is that you don’t know ahead of time how much text a user will enter into their shell. You can’t simply allocate a block and hope they don’t exceed it. Instead, you need to start with a block, and if they do exceed it, reallocate with more space. This is a common strategy in C, and we’ll use it to implement `lsh_read_line()`.

```c
#define LSH_RL_BUFSIZE 1024
char *lsh_read_line(void)
{
  int bufsize = LSH_RL_BUFSIZE;
  int position = 0;
  char *buffer = malloc(sizeof(char) * bufsize);
  int c;

  if (!buffer) {
    fprintf(stderr, "lsh: allocation error\n");
    exit(EXIT_FAILURE);
  }

  while (1) {
    // Read a character
    c = getchar();

    // If we hit EOF, replace it with a null character and return.
    if (c == EOF || c == '\n') {
      buffer[position] = '\0';
      return buffer;
    } else {
      buffer[position] = c;
    }
    position++;

    // If we have exceeded the buffer, reallocate.
    if (position >= bufsize) {
      bufsize += LSH_RL_BUFSIZE;
      buffer = realloc(buffer, bufsize);
      if (!buffer) {
        fprintf(stderr, "lsh: allocation error\n");
        exit(EXIT_FAILURE);
      }
    }
  }
}
```

The first part is a lot of declarations. If you hadn’t noticed, I prefer to keep the old C style of declaring variables before the rest of the code. The meat of the function is within the (apparently infinite) `while (1)` loop. In the loop, we read a character (and store it as an int, not a char, that’s important! EOF is an integer, not a character, and if you want to check for it, you need to use an int. This is a common beginner C mistake.). If it’s the newline, or `EOF`, we null terminate our current string and return it. Otherwise, we add the character to our existing string.

Next, we see whether the next character will go outside of our current buffer size. If so, we reallocate our buffer (checking for allocation errors) before continuing. And that’s really it.

Those who are intimately familiar with newer versions of the C library may note that there is a `getline()` function in stdio.h that does most of the work we just implemented. To be completely honest, I didn’t know it existed until after I wrote this code. This function was a GNU extension to the C library until 2008, when it was added to the specification, so most modern Unixes should have it now. I’m leaving my existing code the way it is, and I encourage people to learn it this way first before using getline. You’d be robbing yourself of a learning opportunity if you didn’t! Anyhow, with getline, the function becomes easier:

```c
char *lsh_read_line(void)
{
  char *line = NULL;
  ssize_t bufsize = 0; // have getline allocate a buffer for us

  if (getline(&line, &bufsize, stdin) == -1){
    if (feof(stdin)) {
      exit(EXIT_SUCCESS);  // We recieved an EOF
    } else  {
      perror("readline");
      exit(EXIT_FAILURE);
    }
  }

  return line;
}
```

This is not 100% trivial because we still need to check for `EOF` or errors while reading. `EOF` (end of file) means that either we were reading commands from a text file which we’ve reached the end of, or the user typed Ctrl-D, which signals end-of-file. Either way, it means we should exit successfully, and if any other error occurs, we should fail after printing the error.

## Parsing the line

OK, so if we look back at the loop, we see that we now have implemented `lsh_read_line()`, and we have the line of input. Now, we need to parse that line into a list of arguments. I’m going to make a glaring simplification here, and say that we won’t allow quoting or backslash escaping in our command line arguments. Instead, we will simply use whitespace to separate arguments from each other. So the command echo "this message" would not call echo with a single argument this message, but rather it would call echo with two arguments: "this and message".

With those simplifications, all we need to do is “tokenize” the string using whitespace as delimiters. That means we can break out the classic library function strtok to do some of the dirty work for us.

```c
#define LSH_TOK_BUFSIZE 64
#define LSH_TOK_DELIM " \t\r\n\a"
char **lsh_split_line(char *line)
{
  int bufsize = LSH_TOK_BUFSIZE, position = 0;
  char **tokens = malloc(bufsize * sizeof(char*));
  char *token;

  if (!tokens) {
    fprintf(stderr, "lsh: allocation error\n");
    exit(EXIT_FAILURE);
  }

  token = strtok(line, LSH_TOK_DELIM);
  while (token != NULL) {
    tokens[position] = token;
    position++;

    if (position >= bufsize) {
      bufsize += LSH_TOK_BUFSIZE;
      tokens = realloc(tokens, bufsize * sizeof(char*));
      if (!tokens) {
        fprintf(stderr, "lsh: allocation error\n");
        exit(EXIT_FAILURE);
      }
    }

    token = strtok(NULL, LSH_TOK_DELIM);
  }
  tokens[position] = NULL;
  return tokens;
}
```

If this code looks suspiciously similar to `lsh_read_line()`, it’s because it is! We are using the same strategy of having a buffer and dynamically expanding it. But this time, we’re doing it with a null-terminated array of pointers instead of a null-terminated array of characters.

At the start of the function, we begin tokenizing by calling `strtok`. It returns a pointer to the first token. What `strtok()` actually does is return pointers to within the string you give it, and place `\0` bytes at the end of each token. We store each pointer in an array (buffer) of character pointers.

Finally, we reallocate the array of pointers if necessary. The process repeats until no token is returned by strtok, at which point we null-terminate the list of tokens.

So, once all is said and done, we have an array of tokens, ready to execute. Which begs the question, how do we do that?

## How shells start processes

Now, we’re really at the heart of what a shell does. Starting processes is the main function of shells. So writing a shell means that you need to know exactly what’s going on with processes and how they start. That’s why I’m going to take us on a short diversion to discuss processes in Unix-like operating systems.

There are only two ways of starting processes on Unix. The first one (which almost doesn’t count) is by being `Init`. You see, when a Unix computer boots, its kernel is loaded. Once it is loaded and initialized, the kernel starts only one process, which is called `Init`. This process runs for the entire length of time that the computer is on, and it manages loading up the rest of the processes that you need for your computer to be useful.

Since most programs aren’t `Init`, that leaves only one practical way for processes to get started: the `fork()` system call. When this function is called, the operating system makes a duplicate of the process and starts them both running. The original process is called the “parent”, and the new one is called the “child”. `fork()` returns `0` to the child process, and it returns to the parent the process ID number (PID) of its child. In essence, this means that the only way for new processes is to start is by an existing one duplicating itself.

This might sound like a problem. Typically, when you want to run a new process, you don’t just want another copy of the same program – you want to run a different program. That’s what the `exec()` system call is all about. It replaces the current running program with an entirely new one. This means that when you call exec, the operating system stops your process, loads up the new program, and starts that one in its place. A process never returns from an `exec()` call (unless there’s an error).

With these two system calls, we have the building blocks for how most programs are run on Unix. First, an existing process forks itself into two separate ones. Then, the child uses `exec()` to replace itself with a new program. The parent process can continue doing other things, and it can even keep tabs on its children, using the system call `wait()`.

Phew! That’s a lot of information, but with all that background, the following code for launching a program will actually make sense:

```c
int lsh_launch(char **args)
{
  pid_t pid, wpid;
  int status;

  pid = fork();
  if (pid == 0) {
    // Child process
    if (execvp(args[0], args) == -1) {
      perror("lsh");
    }
    exit(EXIT_FAILURE);
  } else if (pid < 0) {
    // Error forking
    perror("lsh");
  } else {
    // Parent process
    do {
      wpid = waitpid(pid, &status, WUNTRACED);
    } while (!WIFEXITED(status) && !WIFSIGNALED(status));
  }

  return 1;
}
```

Alright. This function takes the list of arguments that we created earlier. Then, it forks the process, and saves the return value. Once `fork()` returns, we actually have two processes running concurrently. The child process will take the first if condition (where `pid == 0`).

In the child process, we want to run the command given by the user. So, we use one of the many variants of the exec system call, execvp. The different variants of exec do slightly different things. Some take a variable number of string arguments. Others take a list of strings. Still others let you specify the environment that the process runs with. This particular variant expects a program name and an array (also called a vector, hence the `v`) of string arguments (the first one has to be the program name). The `p` means that instead of providing the full file path of the program to run, we’re going to give its name, and let the operating system search for the program in the path.

If the exec command returns `-1` (or actually, if it returns at all), we know there was an error. So, we use perror to print the system’s error message, along with our program name, so users know where the error came from. Then, we exit so that the shell can keep running.

The second condition (`pid < 0`) checks whether `fork()` had an error. If so, we print it and keep going – there’s no handling that error beyond telling the user and letting them decide if they need to quit.

The third condition means that `fork()` executed successfully. The parent process will land here. We know that the child is going to execute the process, so the parent needs to wait for the command to finish running. We use `waitpid()` to wait for the process’s state to change. Unfortunately, `waitpid()` has a lot of options (like `exec()`). Processes can change state in lots of ways, and not all of them mean that the process has ended. A process can either exit (normally, or with an error code), or it can be killed by a signal. So, we use the macros provided with `waitpid()` to wait until either the processes are exited or killed. Then, the function finally returns a `1`, as a signal to the calling function that we should prompt for input again.

## Shell Builtins

You may have noticed that the `lsh_loop()` function calls `lsh_execute()`, but above, we titled our function `lsh_launch()`. This was intentional! You see, most commands a shell executes are programs, but not all of them. Some of them are built right into the shell.

The reason is actually pretty simple. If you want to change directory, you need to use the function `chdir()`. The thing is, the current directory is a property of a process. So, if you wrote a program called `cd` that changed directory, it would just change its own current directory, and then terminate. Its parent process’s current directory would be unchanged. Instead, the shell process itself needs to execute `chdir()`, so that its own current directory is updated. Then, when it launches child processes, they will inherit that directory too.

Similarly, if there was a program named `exit`, it wouldn’t be able to exit the shell that called it. That command also needs to be built into the shell. Also, most shells are configured by running configuration scripts, like `~/.bashrc`. Those scripts use commands that change the operation of the shell. These commands could only change the shell’s operation if they were implemented within the shell process itself.

So, it makes sense that we need to add some commands to the shell itself. The ones I added to my shell are cd, exit, and help. Here are their function implementations below:

```c
/*
  Function Declarations for builtin shell commands:
 */
int lsh_cd(char **args);
int lsh_help(char **args);
int lsh_exit(char **args);

/*
  List of builtin commands, followed by their corresponding functions.
 */
char *builtin_str[] = {
  "cd",
  "help",
  "exit"
};

int (*builtin_func[]) (char **) = {
  &lsh_cd,
  &lsh_help,
  &lsh_exit
};

int lsh_num_builtins() {
  return sizeof(builtin_str) / sizeof(char *);
}

/*
  Builtin function implementations.
*/
int lsh_cd(char **args)
{
  if (args[1] == NULL) {
    fprintf(stderr, "lsh: expected argument to \"cd\"\n");
  } else {
    if (chdir(args[1]) != 0) {
      perror("lsh");
    }
  }
  return 1;
}

int lsh_help(char **args)
{
  int i;
  printf("Stephen Brennan's LSH\n");
  printf("Type program names and arguments, and hit enter.\n");
  printf("The following are built in:\n");

  for (i = 0; i < lsh_num_builtins(); i++) {
    printf("  %s\n", builtin_str[i]);
  }

  printf("Use the man command for information on other programs.\n");
  return 1;
}

int lsh_exit(char **args)
{
  return 0;
}
```

There are three parts to this code. The first part contains forward declarations of my functions. A forward declaration is when you declare (but don’t define) something, so that you can use its name before you define it. The reason I do this is because `lsh_help()` uses the array of builtins, and the arrays contain `lsh_help()`. The cleanest way to break this dependency cycle is by forward declaration.

The next part is an array of builtin command names, followed by an array of their corresponding functions. This is so that, in the future, builtin commands can be added simply by modifying these arrays, rather than editing a large “switch” statement somewhere in the code. If you’re confused by the declaration of `builtin_func`, that’s OK! I am too. It’s an array of function pointers (that take array of strings and return an int). Any declaration involving function pointers in C can get really complicated. I still look up how function pointers are declared myself!1

Finally, I implement each function. The `lsh_cd()` function first checks that its second argument exists, and prints an error message if it doesn’t. Then, it calls `chdir()`, checks for errors, and returns. The help function prints a nice message and the names of all the builtins. And the exit function returns `0`, as a signal for the command loop to terminate.

## Putting together builtins and processes

The last missing piece of the puzzle is to implement `lsh_execute()`, the function that will either launch a builtin, or a process. If you’re reading this far, you’ll know that we’ve set ourselves up for a really simple function:

```c
int lsh_execute(char **args)
{
  int i;

  if (args[0] == NULL) {
    // An empty command was entered.
    return 1;
  }

  for (i = 0; i < lsh_num_builtins(); i++) {
    if (strcmp(args[0], builtin_str[i]) == 0) {
      return (*builtin_func[i])(args);
    }
  }

  return lsh_launch(args);
}
```

All this does is check if the command equals each builtin, and if so, run it. If it doesn’t match a builtin, it calls `lsh_launch()` to launch the process. The one caveat is that args might just contain `NULL`, if the user entered an empty string, or just whitespace. So, we need to check for that case at the beginning.

## Putting it all together

That’s all the code that goes into the shell. If you’ve read along, you should understand completely how the shell works. To try it out (on a Linux machine), you would need to copy these code segments into a file (`main.c`), and compile it. Make sure to only include one implementation of `lsh_read_line()`. You’ll need to include the following headers at the top. I’ve added notes so that you know where each function comes from.

- `#include <sys/wait.h>` &rarr; `waitpid()` and associated macros.
- `#include <unistd.h>` &rarr; `chdir()`, `fork()`, `exec()` & `pid_t`.
- `#include <stdlib.h>` &rarr; `malloc()`, `realloc()`, `free()`, `exit()`, `execvp()`, `EXIT_SUCCESS` & `EXIT_FAILURE`.
- `#include <stdio.h>` &rarr; `fprintf()`, `printf()`, `stderr`, `getchar()` & `perror()`.
- `#include <string.h>` &rarr; `strcmp()` & `strtok()`.

Once you have the code and headers, it should be as simple as running `gcc -o main main.c` to compile it, and then `./main` to run it.

Alternatively, you can get the code from GitHub. That link goes straight to the current revision of the code at the time of this writing– I may choose to update it and add new features someday in the future. If I do, I’ll try my best to update this article with the details and implementation ideas.

## Wrap up

If you read this and wondered how in the world I knew how to use those system calls, the answer is simple: `man` pages. In `man 3p` there is thorough documentation on every system call. If you know what you’re looking for, and you just want to know how to use it, the man pages are your best friend. If you don’t know what sort of interface the C library and Unix offer you, I would point you toward the POSIX Specification, specifically Section 13, “Headers”. You can find each header and everything it is required to define in there.

Obviously, this shell isn’t feature-rich. Some of its more glaring omissions are:

- Only whitespace separating arguments, no quoting or backslash escaping.
- No piping or redirection.
- Few standard builtins.
- No globbing.

The implementation of all of this stuff is really interesting, but way more than I could ever fit into an article like this. If I ever get around to implementing any of them, I’ll be sure to write a follow-up about it. But I’d encourage any reader to try implementing this stuff yourself. If you’re met with success, drop me a line in the comments below, I’d love to see the code.

And finally, thanks for reading this tutorial (if anyone did). I enjoyed writing it, and I hope you enjoyed reading it. Let me know what you think in the comments!

---

## Why are scripting languages (e.g. Perl, Python, and Ruby) not suitable as shell languages?

*Retrieved from [StackOverflow](https://stackoverflow.com/questions/3637668/why-are-scripting-languages-e-g-perl-python-and-ruby-not-suitable-as-shell/3640403#3640403).*

There are a couple of differences that I can think of; just thoughtstreaming here, in no particular order:

1. Python & Co. are designed to be good at scripting. Bash & Co. are designed to be only good at scripting, with absolutely no compromise. IOW: Python is designed to be good both at scripting and non-scripting, Bash cares only about scripting.
2. Bash & Co. are untyped, Python & Co. are strongly typed, which means that the number 123, the string 123 and the file 123 are quite different. They are, however, not statically typed, which means they need to have different literals for those, in order to keep them apart.
3. Python & Co. are designed to scale up to 10000, 100000, maybe even 1000000 line programs, Bash & Co. are designed to scale down to 10 character programs.
4. In Bash & Co., files, directories, file descriptors, processes are all first-class objects, in Python, only Python objects are first-class, if you want to manipulate files, directories etc., you have to wrap them in a Python object first.
5. Shell programming is basically dataflow programming. Nobody realizes that, not even the people who write shells, but it turns out that shells are quite good at that, and general-purpose languages not so much. In the general-purpose programming world, dataflow seems to be mostly viewed as a concurrency model, not so much as a programming paradigm.

*Example:*

```ruby
    Type            | Ruby             | Bash    
    -----------------------------------------
    number          | 123              | 123
    string          | '123'            | 123
    regexp          | /123/            | 123
    file            | File.open('123') | 123
    file descriptor | IO.open('123')   | 123
    URI             | URI.parse('123') | 123
    command         | `123`            | 123
```

I have the feeling that trying to address these points by bolting features or DSLs onto a general-purpose programming language doesn't work. At least, I have yet to see a convincing implementation of it. There is RuSH (Ruby shell), which tries to implement a shell in Ruby, there is rush, which is an internal DSL for shell programming in Ruby, there is Hotwire, which is a Python shell, but IMO none of those come even close to competing with Bash, Zsh, fish and friends.

Actually, IMHO, the best current shell is Microsoft PowerShell, which is very surprising considering that for several decades now, Microsoft has continually had the worst shells evar. I mean, COMMAND.COM? Really? (Unfortunately, they still have a crappy terminal. It's still the "command prompt" that has been around since, what? Windows 3.0?)

PowerShell was basically created by ignoring everything Microsoft has ever done (COMMAND.COM, CMD.EXE, VBScript, JScript) and instead starting from the Unix shell, then removing all backwards-compatibility cruft (like backticks for command substitution) and massaging it a bit to make it more Windows-friendly (like using the now unused backtick as an escape character instead of the backslash which is the path component separator character in Windows). After that, is when the magic happens.

They address problem 1 and 3 from above, by basically making the opposite choice compared to Python. Python cares about large programs first, scripting second. Bash cares only about scripting. PowerShell cares about scripting first, large programs second. A defining moment for me was watching a video of an interview with Jeffrey Snover (PowerShell's lead designer), when the interviewer asked him how big of a program one could write with PowerShell and Snover answered without missing a beat: "80 characters." At that moment I realized that this is finally a guy at Microsoft who "gets" shell programming (probably related to the fact that PowerShell was neither developed by Microsoft's programming language group (i.e. lambda-calculus math nerds) nor the OS group (kernel nerds) but rather the server group (i.e. sysadmins who actually use shells)), and that I should probably take a serious look at PowerShell.

Number 2 is solved by having arguments be statically typed. So, you can write just 123 and PowerShell knows whether it is a string or a number or a file, because the cmdlet (which is what shell commands are called in PowerShell) declares the types of its arguments to the shell. This has pretty deep ramifications: unlike Unix, where each command is responsible for parsing its own arguments (the shell basically passes the arguments as an array of strings), argument parsing in PowerShell is done by the shell. The cmdlets specify all their options and flags and arguments, as well as their types and names and documentation(!) to the shell, which then can perform argument parsing, tab completion, IntelliSense, inline documentation popups etc. in one centralized place. (This is not revolutionary, and the PowerShell designers acknowledge shells like the DIGITAL Command Language (DCL) and the IBM OS/400 Command Language (CL) as prior art. For anyone who has ever used an AS/400, this should sound familiar. In OS/400, you can write a shell command and if you don't know the syntax of certain arguments, you can simply leave them out and hit F4, which will bring a menu (similar to an HTML form) with labelled fields, dropdown, help texts etc. This is only possible because the OS knows about all the possible arguments and their types.) In the Unix shell, this information is often duplicated three times: in the argument parsing code in the command itself, in the bash-completion script for tab-completion and in the manpage.

Number 4 is solved by the fact that PowerShell operates on strongly typed objects, which includes stuff like files, processes, folders and so on.

Number 5 is particularly interesting, because PowerShell is the only shell I know of, where the people who wrote it were actually aware of the fact that shells are essentially dataflow engines and deliberately implemented it as a dataflow engine.

Another nice thing about PowerShell are the naming conventions: all cmdlets are named Action-Object and moreover, there are also standardized names for specific actions and specific objects. (Again, this should sound familar to OS/400 users.) For example, everything which is related to receiving some information is called Get-Foo. And everything operating on (sub-)objects is called Bar-ChildItem. So, the equivalent to ls is Get-ChildItem (although PowerShell also provides builtin aliases ls and dir – in fact, whenever it makes sense, they provide both Unix and CMD.EXE aliases as well as abbreviations (gci in this case)).

But the killer feature IMO is the strongly typed object pipelines. While PowerShell is derived from the Unix shell, there is one very important distinction: in Unix, all communication (both via pipes and redirections as well as via command arguments) is done with untyped, unstructured strings. In PowerShell, it's all strongly typed, structured objects. This is so incredibly powerful that I seriously wonder why noone else has thought of it. (Well, they have, but they never became popular.) In my shell scripts, I estimate that up to one third of the commands is only there to act as an adapter between two other commands that don't agree on a common textual format. Many of those adapters go away in PowerShell, because the cmdlets exchange structured objects instead of unstructured text. And if you look inside the commands, then they pretty much consist of three stages: parse the textual input into an internal object representation, manipulate the objects, convert them back into text. Again, the first and third stage basically go away, because the data already comes in as objects.

However, the designers have taken great care to preserve the dynamicity and flexibility of shell scripting through what they call an Adaptive Type System.

Anyway, I don't want to turn this into a PowerShell commercial. There are plenty of things that are not so great about PowerShell, although most of those have to do either with Windows or with the specific implementation, and not so much with the concepts. (E.g. the fact that it is implemented in .NET means that the very first time you start up the shell can take up to several seconds if the .NET framework is not already in the filesystem cache due to some other application that needs it. Considering that you often use the shell for well under a second, that is completely unacceptable.)

The most important point I want to make is that if you want to look at existing work in scripting languages and shells, you shouldn't stop at Unix and the Ruby/Python/Perl/PHP family. For example, Tcl was already mentioned. Rexx would be another scripting language. Emacs Lisp would be yet another. And in the shell realm there are some of the already mentioned mainframe/midrange shells such as the OS/400 command line and DCL. Also, Plan9's rc.