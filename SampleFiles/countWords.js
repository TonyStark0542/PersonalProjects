const arr = ['apple','orange','apple','apple','banana'];

const wordCount = countword(arr);

console.log(wordCount);

function countword(arr){
    const wordcount = {};

    for(const word in arr){
        if(wordcount[word]){
            wordcount[word]++;
        }
        else{
            wordcount[word] = 1;
        }
    }

    return wordcount;
}