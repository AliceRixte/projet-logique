(******************************************************************************)
(*                                                                            *)
(*                      INVERSION DE MD* VIA SAT SOLVEUR                      *)
(*                                                                            *)
(*                      Projet Logique 2016 - Partie SAT                      *)
(*   Auteur, license, etc.                                                    *)
(******************************************************************************)

open Printf
open Param
       
type var = int
type literal =
  | Pos of var
  | Neg of var
type clause = literal list
type cnf = clause list

type formula =
  | Const of bool
  | Lit of literal
  | Not of formula
  | And of formula*formula
  | Or of formula*formula
  | Xor of formula*formula
  | Imply of formula*formula
  | Equiv of formula*formula

let displayLit l = match l with
  | Pos d -> sprintf "+%d" d
  | Neg d -> sprintf "-%d" d

let rec displayFormula = function
  | Const b -> sprintf "%b" b
  | Lit l -> displayLit l
  | Not f -> sprintf "Not[%s]" (displayFormula f)
  | And (f1,f2) -> sprintf "[%s] /\\ [%s]" (displayFormula f1) (displayFormula f2)
  | Or (f1,f2) -> sprintf "(%s) \\/ (%s)" (displayFormula f1) (displayFormula f2)
  | Xor (f1,f2) -> sprintf "(%s) + (%s)" (displayFormula f1) (displayFormula f2)
  | Imply (f1, f2) -> sprintf "{%s} ==> {%s}" (displayFormula f1) (displayFormula f2)
  | Equiv (f1,f2) -> sprintf "{%s} <==> {%s}" (displayFormula f1) (displayFormula f2)
			     

let rec simple  f = match f with 
  |Const b -> Const b
  |Lit l -> Lit l
  |Not f2 ->
    begin 
      match f2 with 
      |Const(b) -> Const(not b)
      |Or(f3,f4) -> simple(And (Not(f3),Not(f4)))
      |And(f3,f4) -> simple (Or (Not(f3),Not(f4)))
      |Not f3 -> simple(f3)
      |Lit l -> (match l with 
	|Pos d -> Lit (Neg d)
	|Neg d -> Lit (Pos d))
      |Imply(f3,f4) -> simple(And(f3,Not(f4)))
      |Equiv(f3,f4) -> simple(Xor(f3,f4))
      |Xor(f3,f4) -> simple(Equiv(f3,f4))
    end
  |Or(f1,f2)-> (match  simple f1, simple f2 with 
    |(_,Const(true)) |(Const(true),_)  -> Const(true)
    |(a,Const(false)) -> a
    |(Const(false),a) -> a
    |(a,b) -> Or(a,b))
  |And(f1,f2)-> (match  simple f1, simple f2 with 
    |(_,Const(false)) |(Const(false),_)  -> Const(false)
    |(a,Const(true)) -> a
    |(Const(true),a) -> a
    |(a,b) -> And(a,b))
  |Xor(f1,f2) -> simple(Or(And(Not(f1),f2),And(f1,Not(f2))))
  |Imply(f1,f2) -> simple(Or(Not(f1),f2))
  |Equiv(f1,f2) -> simple(And(Imply(f1,f2),Imply(f2,f1)))
    

let subst f tau = f		(* [TODO] *)
  
let formulaeToCnf fl = 
  let rec simpleToPre f = match f with 
    |Const _ | Lit _ -> f
    |Or(And(f1,f2),f3) |Or(f3,And(f1,f2)) -> And(simpleToPre(Or(f1,f3)), simpleToPre(Or(f2,f3)))
    |And(f1,f2) -> And(simpleToPre f1, simpleToPre f2)
    |_ -> f
  in
  
  let rec preToCNF f = match f with 
    |Lit l -> [[l]]
    |Or(f1,f2) -> [(List.hd (preToCNF f1)) @ (List.hd (preToCNF f2))]
    |And(f1,f2) -> (preToCNF f1)@(preToCNF f2) 
    |_ -> [[]]
  in 
  preToCNF (simpleToPre (simple fl))

let rec displayClause c = match c with
  |[] -> ""
  |[l] -> displayLit l
  |l::q -> (displayLit l)^"\\/"^(displayClause q)
	      
let rec displayCnf cnf = match cnf with 
  |[] -> ""
  |[c] -> "{"^displayClause c^"}"
  | c::q -> "{"^(displayClause c)^ "} /\\ "^(displayCnf q)

(*** TEST ***)
let dummyCNF =
  [[Pos 1;Pos 2;Pos 3];
   [Pos 2;Pos 3;Pos 4];
   [Pos 3;Pos 4;Neg 1]
  ]
let sat_solver = ref "./minisat"

(** Return the result of minisat called on [cnf] **)
let testCNF cnf = 
  let cnf_display = displayCnf cnf in
  let fn_cnf = "temp.out" in
  let oc = open_out fn_cnf in
  Printf.fprintf oc  "%s\n" cnf_display;
  close_out oc;
  let resc = (Unix.open_process_in
		(!sat_solver ^ " \"" ^ (String.escaped fn_cnf)
		 ^ "\"") : in_channel) in
  let resSAT = let acc = ref [] in
	       try while true do
		     acc := (input_line resc) :: !acc
		   done; ""
	       with End_of_file ->
		 close_in resc;
		 if List.length !acc = 0
		 then begin
		     log ~level:High "It seems that there is no executable called 'minisat' at top level.";
		     exit 0;
		   end
		 else String.concat "\n" (List.rev !acc) in
  close_in resc;
  List.hd (List.rev (Str.split (Str.regexp " +") resSAT))
	   
let test () =
  Printf.printf "%s\n" (displayFormula (simple (Not(And(Lit(Pos(1)),Lit(Pos(2)))))));
  Printf.printf "%s\n" (displayFormula (simple (Xor(Lit(Pos(1)),Lit(Neg(1))))));
  Printf.printf "%s\n" (displayFormula (simple (Not(Equiv(Lit(Neg(1)),Not(And(Lit(Pos(1)),Lit(Neg(2)))))))));
  Printf.printf "%s\n" (displayCnf (formulaeToCnf (Not(And(Lit(Pos(1)),Lit(Pos(2)))))));
  Printf.printf "%s\n" (displayCnf (formulaeToCnf (Xor(Lit(Pos(1)),Lit(Neg(1))))));
  Printf.printf "%s\n" (displayCnf (formulaeToCnf (Not(Equiv(Lit(Neg(1)),Not(And(Lit(Pos(1)),Lit(Neg(2)))))))));