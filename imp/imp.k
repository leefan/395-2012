module IMP
  syntax AExp ::= Int | Id | String
  	      	| Id "(" AExp ")" [strict(2)]
                > "(" AExp ")"    [bracket]
                > AExp "*" AExp   [seqstrict, left]
                | AExp "/" AExp   [seqstrict, left]
                > AExp "+" AExp   [seqstrict, left]
                | AExp "-" AExp   [seqstrict, left]
                | "read" "()"
  syntax BExp ::= Bool
                | "(" BExp ")"    [bracket]
                | AExp "<=" AExp  [seqstrict]
                | AExp ">=" AExp 
                > BExp "and" BExp [strict(1)]
                | "not" BExp      [strict]
  syntax Stmt ::= StmtVal
                | "print" "(" AExps ")"   [strict]
                | Id ":=" AExp            [strict(2)]
                | "if" BExp "then" Stmt "else" Stmt  [strict(1)]
                | "while" BExp "do" Stmt
		| "return" AExp           [strict]
                > "spawn" Stmt
                > Stmt ";" Stmt           [strict(1), left]
                | "(" Stmt ")"            [bracket]
                | "{" Block "}"
  syntax StmtVal ::= "skip"
                  

  syntax Block ::= "var" Ids ";" Block
  	       	 | "func" Id "(" Id ")" "=" "{" Block "}" Block
                 | Stmt

  syntax Ids ::= List{Id,","}          [strict]
  syntax AExps ::= List{AExp,","}      [strict]

  syntax AValue  ::= Int
  syntax KResult ::= Bool | String | StmtVal | AValue
                   | "return" AValue
         	 
  configuration <C color="yellow">
                  <threads>
                    <thread multiplicity="*">
                      <k color="green"> $PGM:Block </k>
                      <env color="red"> .Map </env>
                    </thread>
                  </threads>
                  <store color="red"> .Map </store>
                  <allocptr color="cyan"> 0 </allocptr>
                  <in color="magenta" stream="stdin">  .List </in>
                  <out color="Orchid" stream="stdout"> .List </out>
                </C>

  syntax Clos ::= "Closure" "(" Map "," Id "," Block ")"

  rule <k> (func F:Id (X:Id) = { B:Block } BRest:Block => BRest) ...</k>
       <env> Env:Map (. => F |-> Closure(Env,X,B)) </env>
       when notBool(F in keys(Env))

  rule <k> (func F:Id (X:Id) = { B:Block } BRest:Block => BRest) ...</k>
       <env> Env:Map (F |-> _ => F |-> Closure(Env,X,B)) </env>

  syntax K ::= "FEnd" "(" Map ")"

  rule <k> (F:Id (A:Int) => B ~> FEnd(E)) ...</k>
       <env> E:Map( F |-> Closure(Env:Map(X |-> _), X, B)) => 
       	     Env(X |-> N)( F |-> Closure(Env:Map, X, B))</env>
       <store> Rho:Map (. => N |-> A)</store>
       <allocptr> N:Int => N +Int 1 </allocptr>
       when notBool(X in keys(Env))

  rule <k> (F:Id (A:Int) => B ~> FEnd(E)) ...</k>
       <env> E:Map( F |-> Closure(Env:Map, X, B)) => 
       	     Env(X |-> N)( F |-> Closure(Env:Map, X, B))</env>
       <store> Rho:Map (. => N |-> A)</store>
       <allocptr> N:Int => N +Int 1 </allocptr>


  rule <k> (return Res:AValue ~> FEnd(E:Map) => Res:AValue) ...</k>
        <env> Env:Map => E </env>

  rule return Res:AValue ; S:Stmt => return Res:AValue

  rule <k> var (X:Id, Xs:Ids => Xs) ; _ ... </k>
       <env> Env (. => X |-> N) </env>
       <store> Store:Map (. => N |-> 0) </store>
       <allocptr> (N => N +Int 1) </allocptr>
       when notBool(X in keys(Env))

  rule <k> var (X:Id, Xs:Ids => Xs) ; _ ... </k>
       <env> Env (X |-> N2 => X |-> N) </env>
       <store> Store:Map (. => N |-> 0) </store>
       <allocptr> (N => N +Int 1) </allocptr>

  rule var .Ids ; B => B     [structural]

  rule <k> (X:Id := I1:Int => skip) ... </k>
       <env> Env:Map (X |-> N:Int) </env>
       <store> Store:Map (N |-> I2 => N |-> I1) </store>   [transition]

  rule I1:Int + I2:Int => I1 +Int I2 
  rule I1:String + I2:String => I1 +String I2 
  rule I1:Int - I2:Int => I1 -Int I2 
  rule I1:Int * I2:Int => I1 *Int I2 
  rule I1:Int / I2:Int => I1 /Int I2 when I2 =/=Int 0
  rule <k> I1:Int / 0 ...</k> => <k> "div0" </k>

  rule I1:Int <= I2:Int => I1 <=Int I2        
  rule A:AExp >= B:AExp => B <= A         [structural]

  rule if true then S:Stmt else _ => S
  rule if false then _ else S:Stmt => S

  rule not false => true
  rule not true => false

  rule true and B:BExp => B
  rule false and B:BExp => false

  rule skip ; S:Stmt => S    [structural]

  rule while B:BExp do S:Stmt =>
       if B then (S ; while B do S) else skip

  rule <k> (X:Id=>I) ...</k>
       <env> Env(X |-> N) </env>
       <store> Store(N |-> I) </env>                        [transition]

  syntax Printable ::= Int | String
  rule <k> print(P:Printable,AEs:AExps => AEs) ...</k>
       <out>... (. => ListItem(P)) </out>                   [transition]
  rule print(.AExps) => skip

  rule <k> (read() => I:Int) ...</k>       
       <in> (ListItem(I) => .) ... </in>

  syntax K ::= "env" "(" Map ")"

  rule <k> {B:Block} => B ~> env(Rho) ...</k>
       <env> Rho:Map </env>

  rule <k> (skip ~> env(Rho:Map) => skip) ...</k>
       <env> Rho2:Map => Rho </env>

  rule <k> (spawn S => skip)  ...</k>
       <env> E </env>
       (. => <thread> <k> S </k> <env> E </env> </thread>)

  rule (<thread> ... <k> skip </k> ... </thread> => .)  

endmodule
